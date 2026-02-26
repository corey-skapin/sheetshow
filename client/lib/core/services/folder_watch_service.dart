import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/services/clock_service.dart';
import 'package:sheetshow/core/services/workspace_service.dart';
import 'package:sheetshow/features/library/models/folder_model.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/folder_repository.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';

// FolderWatchService — watches the workspace folder for file-system changes
// and keeps the in-app library in sync automatically.

/// Kinds of file-system watch events understood by [FolderWatchService].
enum WatchEventKind { create, delete, move }

/// Factory type for creating the file-system watch stream.
/// Separated so tests can inject a synthetic stream without real I/O.
typedef FileSystemWatcher = Stream<FileSystemEvent> Function(String dirPath);

/// Callable type for fetching the page count of a PDF.
/// Defaults to opening the file with pdfrx; injectable in tests.
typedef PageCountProvider = Future<int?> Function(String pdfPath);

/// Watches the workspace directory recursively and mirrors file-system changes
/// into the SheetShow library database.
///
/// **Self-triggered events** (from in-app renames) are suppressed by calling
/// [suppress] before the rename and [unsuppress] afterwards.
class FolderWatchService {
  FolderWatchService({
    required ScoreRepository scoreRepository,
    required FolderRepository folderRepository,
    required ClockService clockService,
    FileSystemWatcher? fileSystemWatcher,
    PageCountProvider? pageCountProvider,
  })  : _scoreRepository = scoreRepository,
        _folderRepository = folderRepository,
        _clockService = clockService,
        _fileSystemWatcher = fileSystemWatcher ?? _defaultWatcher,
        _pageCountProvider = pageCountProvider ?? _defaultPageCount;

  final ScoreRepository _scoreRepository;
  final FolderRepository _folderRepository;
  final ClockService _clockService;
  final FileSystemWatcher _fileSystemWatcher;
  final PageCountProvider _pageCountProvider;

  final Set<String> _suppressedPaths = {};
  final Map<String, Timer> _debounceTimers = {};
  StreamSubscription<FileSystemEvent>? _sub;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Begins watching [workspacePath] recursively.
  ///
  /// Safe to call multiple times — the previous subscription is cancelled first.
  Future<void> start(String workspacePath) async {
    await _sub?.cancel();
    _sub = _fileSystemWatcher(workspacePath).listen(_scheduleEvent);
  }

  /// Walks [workspacePath] and imports any folders/PDFs not already in the
  /// database. Call once after [start] to populate the library on first launch
  /// (and on subsequent launches to pick up any offline changes).
  ///
  /// Skips the `.sheetshow` internal directory. Idempotent — safe to call
  /// even if the library already contains some or all of the files found.
  Future<void> scanWorkspace(String workspacePath) async {
    final rootDir = Directory(workspacePath);
    if (!await rootDir.exists()) return;

    final dirs = <String>[];
    final pdfs = <String>[];

    await for (final entity in rootDir.list(recursive: true)) {
      final relative = path.relative(entity.path, from: workspacePath);
      // Ignore .sheetshow and everything inside it.
      if (relative == '.sheetshow' ||
          relative.startsWith('.sheetshow${path.separator}')) continue;
      if (entity is Directory) {
        dirs.add(entity.path);
      } else if (entity is File && _isPdf(entity.path)) {
        pdfs.add(entity.path);
      }
    }

    // Create folders parent-first (shorter absolute path = shallower = parent).
    dirs.sort((a, b) => a.length.compareTo(b.length));
    for (final dirPath in dirs) {
      try {
        await _onDirectoryCreated(dirPath);
      } catch (e, st) {
        _unawaited(Future.error(e, st)); // surface via Flutter error handler
      }
    }
    for (final pdfPath in pdfs) {
      try {
        await _onPdfCreated(pdfPath);
      } catch (e, st) {
        _unawaited(Future.error(e, st));
      }
    }
  }

  /// Cancels the file-system subscription and all pending debounce timers.
  void stop() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _sub?.cancel();
    _sub = null;
  }

  // ─── Suppression ───────────────────────────────────────────────────────────

  /// Marks [filePath] so that file-system events for it are ignored until
  /// [unsuppress] is called.
  void suppress(String filePath) =>
      _suppressedPaths.add(filePath.toLowerCase());

  /// Removes [filePath] from the suppression set.
  void unsuppress(String filePath) =>
      _suppressedPaths.remove(filePath.toLowerCase());

  /// Returns `true` if events for [filePath] are currently suppressed.
  bool isSuppressed(String filePath) =>
      _suppressedPaths.contains(filePath.toLowerCase());

  // ─── Testing hook ──────────────────────────────────────────────────────────

  /// Processes a synthetic event immediately (bypasses debounce).
  ///
  /// Only use in tests — in production, events arrive via the real watcher.
  @visibleForTesting
  Future<void> handleEventForTesting({
    required String eventPath,
    required bool isDirectory,
    required WatchEventKind kind,
    String? destination,
  }) =>
      _handleEvent(
        eventPath: eventPath,
        isDirectory: isDirectory,
        kind: kind,
        destination: destination,
      );

  // ─── Internal ──────────────────────────────────────────────────────────────

  void _scheduleEvent(FileSystemEvent event) {
    final key = event.path;
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(
      const Duration(milliseconds: 300),
      () {
        _debounceTimers.remove(key);
        _unawaited(_dispatchFsEvent(event));
      },
    );
  }

  Future<void> _dispatchFsEvent(FileSystemEvent event) async {
    if (event is FileSystemCreateEvent) {
      await _handleEvent(
        eventPath: event.path,
        isDirectory: event.isDirectory,
        kind: WatchEventKind.create,
      );
    } else if (event is FileSystemDeleteEvent) {
      // isDirectory is deprecated (always false on Windows for delete events).
      // Infer: no .pdf extension → treat as potential directory deletion.
      await _handleEvent(
        eventPath: event.path,
        isDirectory: !_isPdf(event.path),
        kind: WatchEventKind.delete,
      );
    } else if (event is FileSystemMoveEvent) {
      await _handleEvent(
        eventPath: event.path,
        isDirectory: event.isDirectory,
        kind: WatchEventKind.move,
        destination: event.destination,
      );
    }
  }

  Future<void> _handleEvent({
    required String eventPath,
    required bool isDirectory,
    required WatchEventKind kind,
    String? destination,
  }) async {
    if (_suppressedPaths.contains(eventPath.toLowerCase())) return;

    if (kind == WatchEventKind.create) {
      if (isDirectory) {
        await _onDirectoryCreated(eventPath);
      } else if (_isPdf(eventPath)) {
        await _onPdfCreated(eventPath);
      }
    } else if (kind == WatchEventKind.delete) {
      if (isDirectory) {
        await _onDirectoryDeleted(eventPath);
      } else if (_isPdf(eventPath)) {
        await _onPdfDeleted(eventPath);
      }
    } else if (kind == WatchEventKind.move) {
      if (isDirectory) {
        if (destination != null) {
          await _onDirectoryMoved(eventPath, destination);
        } else {
          await _onDirectoryDeleted(eventPath);
        }
      } else if (_isPdf(eventPath)) {
        if (destination != null && _isPdf(destination)) {
          await _onPdfMoved(eventPath, destination);
        } else {
          await _onPdfDeleted(eventPath);
        }
      }
    }
  }

  // ─── PDF events ────────────────────────────────────────────────────────────

  Future<void> _onPdfCreated(String pdfPath) async {
    final filename = path.basename(pdfPath);
    final existing = await _scoreRepository.getByFilename(filename);
    if (existing != null) {
      // Score already exists — ensure it has a membership to this folder
      // (mirrors ImportService._importSingleFile deduplication behaviour).
      final dirPath = path.dirname(pdfPath);
      final folder = await _folderRepository.getByDiskPath(dirPath);
      if (folder != null) {
        await _scoreRepository.addToFolder(existing.id, folder.id);
      }
      return;
    }

    final pageCount = await _pageCountProvider(pdfPath);
    if (pageCount == null || pageCount == 0) return;

    final dirPath = path.dirname(pdfPath);
    final folder = await _folderRepository.getByDiskPath(dirPath);
    final title = path.basenameWithoutExtension(pdfPath);

    final score = ScoreModel(
      id: const Uuid().v4(),
      title: title,
      filename: filename,
      localFilePath: pdfPath,
      totalPages: pageCount,
      updatedAt: _clockService.now(),
    );
    await _scoreRepository.insert(score, folderId: folder?.id);
  }

  Future<void> _onPdfDeleted(String pdfPath) async {
    final score = await _scoreRepository.getByFilePath(pdfPath);
    if (score == null) return;
    await _scoreRepository.delete(score.id);
  }

  Future<void> _onPdfMoved(String oldPath, String newPath) async {
    final score = await _scoreRepository.getByFilePath(oldPath);
    if (score == null) return;
    final newFilename = path.basename(newPath);
    await _scoreRepository.updateFilePath(score.id, newPath, newFilename);
  }

  // ─── Directory events ──────────────────────────────────────────────────────

  Future<void> _onDirectoryCreated(String dirPath) async {
    final existing = await _folderRepository.getByDiskPath(dirPath);
    if (existing != null) return;

    final parentDirPath = path.dirname(dirPath);
    final parentFolder = await _folderRepository.getByDiskPath(parentDirPath);

    final folder = FolderModel(
      id: const Uuid().v4(),
      name: path.basename(dirPath),
      parentFolderId: parentFolder?.id,
      createdAt: _clockService.now(),
      updatedAt: _clockService.now(),
      diskPath: dirPath,
    );
    await _folderRepository.create(folder);
  }

  Future<void> _onDirectoryDeleted(String dirPath) async {
    final folder = await _folderRepository.getByDiskPath(dirPath);
    if (folder == null) return;
    await _folderRepository.delete(folder.id);
  }

  Future<void> _onDirectoryMoved(String oldPath, String newPath) async {
    final folder = await _folderRepository.getByDiskPath(oldPath);
    if (folder == null) return;
    await _folderRepository.updateDiskPath(
      folder.id,
      path.basename(newPath),
      newPath,
    );
  }

  // ─── Static helpers ────────────────────────────────────────────────────────

  static bool _isPdf(String filePath) =>
      filePath.toLowerCase().endsWith('.pdf');

  static Stream<FileSystemEvent> _defaultWatcher(String dirPath) =>
      Directory(dirPath).watch(recursive: true);

  static Future<int?> _defaultPageCount(String pdfPath) async {
    try {
      final doc = await PdfDocument.openFile(pdfPath);
      final count = doc.pages.length;
      await doc.dispose();
      return count > 0 ? count : null;
    } catch (_) {
      return null;
    }
  }
}

/// Riverpod provider for [FolderWatchService].
///
/// Automatically starts watching once the workspace database is ready.
final folderWatchServiceProvider =
    FutureProvider<FolderWatchService>((ref) async {
  // Depend on the database being ready first.
  await ref.watch(databaseProvider.future);

  final scoreRepo = ref.watch(scoreRepositoryProvider);
  final folderRepo = ref.watch(folderRepositoryProvider);
  final clockSvc = ref.watch(clockServiceProvider);
  final workspaceService = ref.watch(workspaceServiceProvider);

  final workspacePath = await workspaceService.getWorkspacePath();

  final service = FolderWatchService(
    scoreRepository: scoreRepo,
    folderRepository: folderRepo,
    clockService: clockSvc,
  );

  if (workspacePath != null) {
    await service.start(workspacePath);
    await service.scanWorkspace(workspacePath);
  }
  ref.onDispose(service.stop);
  return service;
});

void _unawaited(Future<void> future) {
  future.catchError((Object error, StackTrace stackTrace) {
    // Log in debug builds to aid diagnosis of unexpected background errors.
    assert(() {
      debugPrint('Unhandled error in _unawaited future: $error');
      debugPrint('Stack trace:\n$stackTrace');
      return true;
    }());

    // Let Flutter's error handling surface the problem instead of hiding it.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'folder_watch_service',
        context: ErrorDescription('While running an unawaited future'),
      ),
    );
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// WorkspaceService — reads/writes the workspace root from AppDocumentsDir/sheetshow_config.json.

/// Manages the workspace root folder configuration.
///
/// All scores live inside the workspace; the SQLite database is stored at
/// `<workspace>/.sheetshow/data.db`.
class WorkspaceService {
  /// Creates a [WorkspaceService].
  ///
  /// Pass [overrideBaseDir] in tests to avoid calling `path_provider`.
  WorkspaceService({String? overrideBaseDir})
      : _overrideBaseDir = overrideBaseDir;

  final String? _overrideBaseDir;

  static const String _configFileName = 'sheetshow_config.json';
  static const String _sheetshowDirName = '.sheetshow';
  static const String _dbFileName = 'data.db';

  Future<Directory> _baseDir() async {
    if (_overrideBaseDir != null) return Directory(_overrideBaseDir);
    return getApplicationDocumentsDirectory();
  }

  /// Returns the configured workspace path, or `null` if not yet set.
  Future<String?> getWorkspacePath() async {
    final dir = await _baseDir();
    final file = File(path.join(dir.path, _configFileName));
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return json['workspacePath'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Persists [workspacePath] to `AppDocumentsDir/sheetshow_config.json`.
  Future<void> setWorkspacePath(String workspacePath) async {
    final dir = await _baseDir();
    final file = File(path.join(dir.path, _configFileName));
    await file.writeAsString(jsonEncode({'workspacePath': workspacePath}));
  }

  /// Removes the workspace configuration so the app returns to the setup
  /// screen on next launch. Does **not** delete any data on disk.
  Future<void> clearWorkspacePath() async {
    final dir = await _baseDir();
    final file = File(path.join(dir.path, _configFileName));
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Creates `<workspace>/.sheetshow/` if it does not already exist.
  Future<void> ensureSheetshowDir(String workspace) async {
    final dir = Directory(path.join(workspace, _sheetshowDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Returns the absolute path where the SQLite database should be opened.
  String getDatabasePath(String workspace) =>
      path.join(workspace, _sheetshowDirName, _dbFileName);
}

/// Riverpod provider for [WorkspaceService].
final workspaceServiceProvider = Provider<WorkspaceService>(
  (_) => WorkspaceService(),
);

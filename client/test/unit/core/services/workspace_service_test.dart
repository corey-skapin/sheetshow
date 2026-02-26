import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sheetshow/core/services/workspace_service.dart';

void main() {
  late Directory tempDir;
  late WorkspaceService sut;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ws_service_test_');
    sut = WorkspaceService(overrideBaseDir: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('WorkspaceService.getWorkspacePath', () {
    test('returns null when config file is absent', () async {
      expect(await sut.getWorkspacePath(), isNull);
    });

    test('returns path when config file is present', () async {
      final configFile = File(path.join(tempDir.path, 'sheetshow_config.json'));
      await configFile
          .writeAsString(jsonEncode({'workspacePath': '/music/scores'}));

      expect(await sut.getWorkspacePath(), '/music/scores');
    });

    test('returns null when config file contains invalid JSON', () async {
      final configFile = File(path.join(tempDir.path, 'sheetshow_config.json'));
      await configFile.writeAsString('not json');

      expect(await sut.getWorkspacePath(), isNull);
    });

    test('returns null when workspacePath key is absent', () async {
      final configFile = File(path.join(tempDir.path, 'sheetshow_config.json'));
      await configFile.writeAsString(jsonEncode({'other': 'value'}));

      expect(await sut.getWorkspacePath(), isNull);
    });
  });

  group('WorkspaceService.setWorkspacePath', () {
    test('writes correct JSON to config file', () async {
      await sut.setWorkspacePath('/my/scores');

      final configFile = File(path.join(tempDir.path, 'sheetshow_config.json'));
      expect(await configFile.exists(), isTrue);
      final json =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      expect(json['workspacePath'], '/my/scores');
    });

    test('overwrites existing config', () async {
      await sut.setWorkspacePath('/old/path');
      await sut.setWorkspacePath('/new/path');

      expect(await sut.getWorkspacePath(), '/new/path');
    });
  });

  group('WorkspaceService.ensureSheetshowDir', () {
    test('creates .sheetshow directory when absent', () async {
      final workspace = path.join(tempDir.path, 'workspace');
      await Directory(workspace).create();

      await sut.ensureSheetshowDir(workspace);

      final sheetshowDir = Directory(path.join(workspace, '.sheetshow'));
      expect(await sheetshowDir.exists(), isTrue);
    });

    test('does not throw if .sheetshow directory already exists', () async {
      final workspace = path.join(tempDir.path, 'workspace');
      final sheetshowDir = Directory(path.join(workspace, '.sheetshow'));
      await sheetshowDir.create(recursive: true);

      await expectLater(sut.ensureSheetshowDir(workspace), completes);
    });
  });

  group('WorkspaceService.getDatabasePath', () {
    test('returns correct .sheetshow/data.db path', () {
      final result = sut.getDatabasePath('/my/workspace');
      expect(result, endsWith(path.join('.sheetshow', 'data.db')));
      expect(result, startsWith('/my/workspace'));
    });
  });

  group('round-trip', () {
    test('setWorkspacePath then getWorkspacePath returns same value', () async {
      await sut.setWorkspacePath('/round/trip/path');
      expect(await sut.getWorkspacePath(), '/round/trip/path');
    });
  });

  group('WorkspaceService.clearWorkspacePath', () {
    test('removes config file so getWorkspacePath returns null', () async {
      await sut.setWorkspacePath('/some/path');
      expect(await sut.getWorkspacePath(), '/some/path');

      await sut.clearWorkspacePath();
      expect(await sut.getWorkspacePath(), isNull);
    });

    test('does not throw when config file does not exist', () async {
      await expectLater(sut.clearWorkspacePath(), completes);
    });
  });
}

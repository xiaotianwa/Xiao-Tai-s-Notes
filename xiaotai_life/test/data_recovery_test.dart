import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/data/app_data_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xiaotai_recovery_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return tempDir.path;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'corrupt local data file is preserved and restored from backup',
    () async {
      final dataFile = File(
        '${tempDir.path}${Platform.pathSeparator}xiaotai_life_data.json',
      );
      await dataFile.writeAsString('{broken json');

      final backupDirectory = Directory(
        '${tempDir.path}${Platform.pathSeparator}xiaotai_life_backups',
      );
      await backupDirectory.create(recursive: true);
      final backupFile = File(
        '${backupDirectory.path}${Platform.pathSeparator}backup_valid.json',
      );
      await backupFile.writeAsString(
        jsonEncode({
          'settings.v1': AppSettings.defaults
              .copyWith(profileName: '恢复后的名字')
              .toJson(),
        }),
      );

      final store = await AppLocalStore.create();
      final notice = store.getDataRecoveryNotice();

      expect(store.getSettings().profileName, '恢复后的名字');
      expect(notice, isNotNull);
      expect(notice!.restoredFromBackup, isTrue);
      expect(notice.restoredBackupPath, backupFile.path);
      expect(await File(notice.corruptFilePath).exists(), isTrue);
    },
  );

  test('rapid local backups keep only the latest file', () async {
    final store = await AppLocalStore.create();

    final first = await store.createBackup();
    final second = await store.createBackup();

    expect(first.id, isNot(second.id));
    expect(first.filePath, isNot(second.filePath));
    expect(await File(first.filePath).exists(), isFalse);
    expect(await File(second.filePath).exists(), isTrue);
    expect(store.getBackups().map((backup) => backup.id), [second.id]);
  });

  test('restore latest backup uses the only retained backup', () async {
    final store = await AppLocalStore.create();
    await store.saveSettings(
      AppSettings.defaults.copyWith(profileName: '可恢复的数据'),
    );
    final valid = await store.createBackup();

    await store.saveSettings(
      AppSettings.defaults.copyWith(profileName: '恢复前的数据'),
    );
    final restored = await store.restoreLatestBackup();

    expect(restored.id, valid.id);
    expect(store.getSettings().profileName, '可恢复的数据');
  });
}

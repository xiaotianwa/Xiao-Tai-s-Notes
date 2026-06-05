import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/data/app_data_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xiaotai_sync_test_');
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

  test('AppSyncConflict keeps server and local snapshots', () {
    final localItem = AppSyncQueueItem(
      id: 'sync_entry_entry_1',
      type: 'entry',
      clientId: 'entry_1',
      clientUpdatedAt: DateTime(2026, 6, 1, 10),
      data: const {'id': 'entry_1', 'title': '本机标题'},
      deletedAt: null,
    );

    final conflict = AppSyncConflict.fromServerJson({
      'type': 'entry',
      'clientId': 'entry_1',
      'reason': 'server_newer',
      'serverItem': {
        'serverUpdatedAt': '2026-06-02T10:00:00.000',
        'data': {'id': 'entry_1', 'title': '云端标题'},
      },
    }, localItem: localItem);

    expect(conflict.key, 'entry:entry_1');
    expect(conflict.localData['title'], '本机标题');
    expect(conflict.serverData['title'], '云端标题');
    expect(conflict.localUpdatedAt, DateTime(2026, 6, 1, 10));
    expect(conflict.serverUpdatedAt, DateTime(2026, 6, 2, 10));
  });

  test('AppSyncStatus serializes conflict detail list', () {
    final status = AppSyncStatus(
      lastConflictCount: 1,
      lastConflicts: [
        AppSyncConflict(
          type: 'memo',
          clientId: 'memo_1',
          reason: 'server_newer',
          localUpdatedAt: DateTime(2026, 6, 1, 9),
          serverUpdatedAt: DateTime(2026, 6, 1, 10),
          localData: const {'content': '本机备忘'},
          serverData: const {'content': '云端备忘'},
        ),
      ],
    );

    final decoded = AppSyncStatus.fromJson(status.toJson());

    expect(decoded.hasConflicts, isTrue);
    expect(decoded.lastConflictCount, 1);
    expect(decoded.lastConflicts.single.clientId, 'memo_1');
    expect(decoded.lastConflicts.single.serverData['content'], '云端备忘');
  });

  test('keepLocalConflict refreshes queued item and clears conflict', () async {
    final store = await AppLocalStore.create();
    await store.saveSyncQueue(const []);

    final oldUpdatedAt = DateTime(2026, 6, 1, 10);
    final queueItem = AppSyncQueueItem(
      id: 'sync_entry_entry_1',
      type: 'entry',
      clientId: 'entry_1',
      clientUpdatedAt: oldUpdatedAt,
      data: const {'id': 'entry_1', 'title': '本机标题'},
      deletedAt: null,
    );
    await store.saveSyncQueue([queueItem]);

    final conflict = AppSyncConflict(
      type: 'entry',
      clientId: 'entry_1',
      reason: 'server_newer',
      localUpdatedAt: oldUpdatedAt,
      serverUpdatedAt: DateTime(2026, 6, 2, 10),
      localData: queueItem.data,
      serverData: const {'id': 'entry_1', 'title': '云端标题'},
    );
    await store.markSyncSucceeded(pushed: 0, pulled: 0, conflicts: [conflict]);

    await store.keepLocalConflict(conflict);

    final queue = store.getSyncQueue();
    expect(queue, hasLength(1));
    expect(queue.single.id, queueItem.id);
    expect(queue.single.data['title'], '本机标题');
    expect(queue.single.clientUpdatedAt.isAfter(oldUpdatedAt), isTrue);
    expect(store.getSyncStatus().lastConflicts, isEmpty);
    expect(store.getSyncStatus().lastConflictCount, 0);
  });

  test('couple task upsert and delete are added to sync queue', () async {
    final store = await AppLocalStore.create();
    await store.saveSyncQueue(const []);

    final task = AppCoupleTask(
      id: 'couple_custom_1',
      index: 101,
      title: '一起整理照片墙',
      completed: true,
      completedAt: DateTime(2026, 6, 3, 12),
    );

    await store.upsertCoupleTask(task);

    final upsertQueue = store.getSyncQueue();
    expect(upsertQueue, hasLength(1));
    expect(upsertQueue.single.type, 'couple_task');
    expect(upsertQueue.single.clientId, task.id);
    expect(upsertQueue.single.data['title'], task.title);
    expect(upsertQueue.single.deletedAt, isNull);

    await store.deleteCoupleTask(task.id);

    final deleteQueue = store.getSyncQueue();
    expect(deleteQueue, hasLength(1));
    expect(deleteQueue.single.type, 'couple_task');
    expect(deleteQueue.single.clientId, task.id);
    expect(deleteQueue.single.data, isEmpty);
    expect(deleteQueue.single.deletedAt, isNotNull);
    expect(store.getCoupleTasks(), isEmpty);
  });

  test('remote couple task items are applied to local store', () async {
    final store = await AppLocalStore.create();

    await store.applyRemoteSyncItem(
      type: 'couple_task',
      clientId: 'couple_custom_remote',
      data: {
        'id': 'couple_custom_remote',
        'index': 120,
        'title': '一起看一次深夜电影',
        'completed': true,
        'completedAt': '2026-06-03T20:30:00.000',
        'imagePath': null,
      },
    );

    final task = store.getCoupleTasks().single;
    expect(task.id, 'couple_custom_remote');
    expect(task.title, '一起看一次深夜电影');
    expect(task.completed, isTrue);
    expect(task.completedAt, DateTime(2026, 6, 3, 20, 30));

    await store.applyRemoteSyncItem(
      type: 'couple_task',
      clientId: task.id,
      data: const {},
      deletedAt: DateTime(2026, 6, 4),
    );

    expect(store.getCoupleTasks(), isEmpty);
  });
}

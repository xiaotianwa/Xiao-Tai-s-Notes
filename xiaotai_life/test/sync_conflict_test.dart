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

  test(
    'new local store does not enqueue default settings before login',
    () async {
      final store = await AppLocalStore.create();

      expect(store.getSettings().profileName, AppSettings.defaults.profileName);
      expect(store.getSyncQueue(), isEmpty);
    },
  );

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

  test('remote anniversary items are applied to local store', () async {
    final store = await AppLocalStore.create();

    await store.applyRemoteSyncItem(
      type: 'anniversary',
      clientId: 'anniversary_remote_love',
      data: {
        'id': 'anniversary_remote_love',
        'title': '第一次旅行',
        'date': '2024-10-01T00:00:00.000',
        'category': 'love',
        'colorName': 'pink',
        'mascotVariant': 'heart',
        'imagePath': null,
        'note': '云端同步回来的纪念日',
        'showCountUp': true,
        'pinnedOnHome': true,
      },
    );

    final anniversary = store.getAnniversaries().single;
    expect(anniversary.id, 'anniversary_remote_love');
    expect(anniversary.title, '第一次旅行');
    expect(anniversary.showCountUp, isTrue);
    expect(anniversary.pinnedOnHome, isTrue);

    await store.applyRemoteSyncItem(
      type: 'anniversary',
      clientId: anniversary.id,
      data: const {},
      deletedAt: DateTime(2026, 6, 5),
    );

    expect(store.getAnniversaries(), isEmpty);
  });

  test(
    'local sync snapshot queues existing anniversaries once per user',
    () async {
      final store = await AppLocalStore.createInMemoryForTesting();
      await store.saveSyncQueue(const []);
      await store.saveAnniversaries([
        AppAnniversary(
          id: 'anniversary_local_love',
          title: '在一起',
          date: DateTime(2024, 5, 20),
          category: 'love',
          colorName: 'pink',
          mascotVariant: 'heart',
          note: '本机已有的纪念日',
          showCountUp: true,
          pinnedOnHome: true,
        ),
      ]);

      final queued = await store.enqueueLocalSyncSnapshot(userId: 'user_1');

      expect(queued, 1);
      final queue = store.getSyncQueue();
      expect(queue, hasLength(1));
      expect(queue.single.type, 'anniversary');
      expect(queue.single.clientId, 'anniversary_local_love');
      expect(queue.single.clientUpdatedAt, DateTime(2024, 5, 20));
      expect(queue.single.data['title'], '在一起');

      final queuedAgain = await store.enqueueLocalSyncSnapshot(
        userId: 'user_1',
      );

      expect(queuedAgain, 0);
      expect(store.getSyncQueue(), hasLength(1));
    },
  );

  test('remote ai messages are applied and deleted from local store', () async {
    final store = await AppLocalStore.create();

    await store.applyRemoteSyncItem(
      type: 'ai_message',
      clientId: 'ai_remote_1',
      data: {
        'id': 'ai_remote_1',
        'role': 'assistant',
        'content': '我会记得这条对话',
        'createdAt': '2026-06-03T20:30:00.000',
      },
    );

    final message = store.getAiMessages().single;
    expect(message.id, 'ai_remote_1');
    expect(message.content, '我会记得这条对话');

    await store.applyRemoteSyncItem(
      type: 'ai_message',
      clientId: message.id,
      data: const {},
      deletedAt: DateTime(2026, 6, 5),
    );

    expect(store.getAiMessages(), isEmpty);
  });

  test('clear ai messages queues remote deletes', () async {
    final store = await AppLocalStore.create();
    await store.saveSyncQueue(const []);
    await store.saveAiMessages([
      AppAiMessage(
        id: 'ai_message_1',
        role: 'user',
        content: '第一条',
        createdAt: DateTime(2026, 6, 3, 20),
      ),
      AppAiMessage(
        id: 'ai_message_2',
        role: 'assistant',
        content: '第二条',
        createdAt: DateTime(2026, 6, 3, 20, 1),
      ),
    ]);

    await store.clearAiMessages();

    expect(store.getAiMessages(), isEmpty);
    final queue = store.getSyncQueue();
    expect(queue, hasLength(2));
    expect(queue.map((item) => item.type).toSet(), {'ai_message'});
    expect(queue.every((item) => item.deletedAt != null), isTrue);
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/data/app_data_store.dart';
import 'package:xiaotai_life/core/sync/app_sync_service.dart';

void main() {
  test('push pending uploads queued items in API-sized batches', () async {
    final store = await AppLocalStore.createInMemoryForTesting();
    final baseTime = DateTime(2026, 6, 1, 10);
    await store.saveSyncQueue(
      List.generate(
        101,
        (index) => AppSyncQueueItem(
          id: 'sync_entry_entry_$index',
          type: 'entry',
          clientId: 'entry_$index',
          clientUpdatedAt: baseTime.add(Duration(minutes: index)),
          data: {'id': 'entry_$index', 'title': '记录$index'},
          deletedAt: null,
        ),
      ),
    );

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final batchSizes = <int>[];
    addTearDown(() async {
      await server.close(force: true);
    });
    unawaited(
      (() async {
        await for (final request in server) {
          expect(request.method, 'POST');
          expect(request.uri.path, '/sync/items/batch');
          expect(request.headers.value('Authorization'), 'Bearer test-token');
          final raw = await utf8.decodeStream(request);
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final items = decoded['items'] as List<dynamic>;
          batchSizes.add(items.length);
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'code': 0,
              'message': 'ok',
              'data': {
                'accepted': items.length,
                'conflicts': <Object?>[],
                'serverTime': '2026-06-03T00:00:00.000Z',
              },
            }),
          );
          await request.response.close();
        }
      })(),
    );

    final result = await AppSyncService(
      store,
      baseUrl: 'http://${server.address.host}:${server.port}',
    ).pushPending(accessToken: 'test-token');

    expect(result.pushed, 101);
    expect(result.conflicts, isEmpty);
    expect(batchSizes, [100, 1]);
    expect(store.getSyncQueue(), isEmpty);
  });
}

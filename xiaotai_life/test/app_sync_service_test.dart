import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/data/app_data_store.dart';
import 'package:xiaotai_life/core/sync/app_sync_service.dart';

void main() {
  test('sync uploads existing local anniversaries before pulling', () async {
    final store = await AppLocalStore.createInMemoryForTesting();
    await store.saveAuthSession(
      AppAuthSession(
        accessToken: 'test-token',
        refreshToken: 'refresh-token',
        userId: 'user_1',
        username: 'tingting',
        role: 'user',
        updatedAt: DateTime(2026, 6, 1),
      ),
    );
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

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final uploadedTypes = <String>[];
    addTearDown(() async {
      await server.close(force: true);
    });
    unawaited(
      (() async {
        await for (final request in server) {
          request.response.headers.contentType = ContentType.json;
          if (request.method == 'POST') {
            expect(request.uri.path, '/sync/items/batch');
            final raw = await utf8.decodeStream(request);
            final decoded = jsonDecode(raw) as Map<String, dynamic>;
            final items = decoded['items'] as List<dynamic>;
            uploadedTypes.addAll(
              items.map((item) {
                final decodedItem = item as Map<String, dynamic>;
                expect(decodedItem['clientId'], 'anniversary_local_love');
                expect(
                  decodedItem['clientUpdatedAt'],
                  DateTime(2024, 5, 20).toIso8601String(),
                );
                return decodedItem['type'] as String;
              }),
            );
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
          } else {
            expect(request.method, 'GET');
            expect(request.uri.path, '/sync/items');
            request.response.write(
              jsonEncode({
                'code': 0,
                'message': 'ok',
                'data': {
                  'items': <Object?>[],
                  'total': 0,
                  'page': 1,
                  'pageSize': 100,
                  'serverTime': '2026-06-03T00:00:00.000Z',
                },
              }),
            );
          }
          await request.response.close();
        }
      })(),
    );

    final result = await AppSyncService(
      store,
      baseUrl: 'http://${server.address.host}:${server.port}',
    ).sync(accessToken: 'test-token');

    expect(result.pushed, 1);
    expect(result.pulled, 0);
    expect(uploadedTypes, ['anniversary']);
    expect(store.getSyncQueue(), isEmpty);
  });

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

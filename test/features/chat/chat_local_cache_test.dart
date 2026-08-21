import 'dart:io';

import 'package:flutter_base/features/chat/data/chat_local_cache.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists chat records per owner and conversation', () async {
    final storage = <String, String>{};
    final cache = ChatLocalCache(
      readString: (key) async => storage[key],
      writeString: (key, value) async {
        storage[key] = value;
      },
    );
    final message = Message(
      msgId: 7,
      content: 'cached message',
      isMe: false,
      time: '10:00',
      isRead: true,
      conversationId: 'alice_me',
      senderId: 'alice',
      timestamp: 1787277600000,
    );

    await cache.save('me', 'alice', [message]);

    final restored = await cache.load('me', 'alice');
    expect(restored, hasLength(1));
    expect(restored.single.msgId, 7);
    expect(restored.single.timestamp, 1787277600000);
    expect(await cache.load('other-account', 'alice'), isEmpty);
  });

  test('returns an empty list for corrupt cached JSON', () async {
    final cache = ChatLocalCache(
      readString: (_) async => '{invalid',
      writeString: (_, _) async {},
    );

    expect(await cache.load('me', 'alice'), isEmpty);
  });

  test('returns an empty list when the cache file cannot be read', () async {
    final cache = ChatLocalCache(
      readString: (_) async => throw const FileSystemException('unreadable'),
      writeString: (_, _) async {},
    );

    expect(await cache.load('me', 'alice'), isEmpty);
  });

  test('reports the newest cached message timestamp', () async {
    final storage = <String, String>{};
    final cache = ChatLocalCache(
      readString: (key) async => storage[key],
      writeString: (key, value) async {
        storage[key] = value;
      },
    );

    await cache.save('me', 'alice', [
      _message(1, 1787277601000),
      _message(2, 1787277603000),
      _message(3, 1787277602000),
    ]);

    expect(await cache.latestTimestamp('me', 'alice'), 1787277603000);
  });
}

Message _message(int id, int timestamp) {
  return Message(
    msgId: id,
    content: '$id',
    isMe: false,
    time: '',
    isRead: true,
    conversationId: 'alice_me',
    timestamp: timestamp,
  );
}

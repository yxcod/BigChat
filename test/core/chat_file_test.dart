import 'dart:io';

import 'package:flutter_base/core/media/chat_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file payload preserves original metadata', () {
    const payload = ChatFilePayload(
      storedName: 'alice_bob_1.pdf',
      originalName: '项目资料.pdf',
      sizeBytes: 2048,
      ownerId: 'alice',
    );

    final restored = ChatFilePayload.parse(payload.encode());

    expect(restored.storedName, 'alice_bob_1.pdf');
    expect(restored.originalName, '项目资料.pdf');
    expect(restored.sizeBytes, 2048);
    expect(restored.ownerId, 'alice');
  });

  test('stored file name is safe and keeps a normal extension', () {
    expect(
      chatFileStoredName(
        ownerId: 'alice',
        targetId: 'group:12',
        messageId: 3,
        originalName: '报告.PDF',
      ),
      'alice_group_12_3.pdf',
    );
  });

  test('files larger than 300MB are rejected before upload', () async {
    final directory = await Directory.systemTemp.createTemp('chat-file-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/oversized.bin');
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(maxChatFileBytes + 1);
    await handle.close();

    await expectLater(
      validateChatFile(file.path),
      throwsA(predicate((error) => error.toString().contains('300MB'))),
    );
  });
}

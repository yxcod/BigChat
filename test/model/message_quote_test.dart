import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'quoted message metadata survives websocket and local cache formats',
    () {
      const quote = MessageQuote(
        messageId: 42,
        senderId: 'alice',
        senderLabel: '小艾',
        preview: '下午三点见。',
        messageType: MessageType.text,
      );

      final fromNetwork = MessageQuote.fromExtendInfo(quote.encodeExtendInfo());
      final cachedMessage = Message.fromJSON(
        Message(
          msgId: 43,
          content: '好的',
          isMe: true,
          time: '15:00',
          isRead: false,
          conversationId: 'alice_bob',
          quote: quote,
        ).toJSON(),
      );

      expect(fromNetwork?.messageId, 42);
      expect(fromNetwork?.senderLabel, '小艾');
      expect(cachedMessage.quote?.preview, '下午三点见。');
    },
  );

  test('quote preview uses media labels and truncates long text', () {
    final image = Message(
      msgId: 1,
      content: 'photo.jpg',
      isMe: false,
      time: '',
      isRead: true,
      conversationId: 'c',
      messageType: MessageType.image,
    );
    final text = Message(
      msgId: 2,
      content: '这是一段很长的聊天内容' * 8,
      isMe: false,
      time: '',
      isRead: true,
      conversationId: 'c',
    );

    expect(messageQuotePreview(image), '[图片]');
    expect(messageQuotePreview(text).endsWith('…'), isTrue);
  });
}

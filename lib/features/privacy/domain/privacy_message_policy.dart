import '../../../model/messageModel.dart';

const String privacyMessagePreviewLabel = '[隐私信息]';

/// Returns in-memory privacy messages that still require an individual read
/// acknowledgement. Privacy messages never participate in the persisted group
/// read watermark, so they must be acknowledged one by one.
List<Message> privacyMessagesAwaitingReadAck(
  Iterable<Message> messages,
  Set<int> acknowledgedMessageIds,
) {
  return messages
      .where(
        (message) =>
            !message.isMe &&
            message.isPrivacy &&
            message.msgId > 0 &&
            !acknowledgedMessageIds.contains(message.msgId),
      )
      .toList(growable: false);
}

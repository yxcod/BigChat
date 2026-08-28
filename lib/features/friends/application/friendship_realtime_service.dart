import '../../../api/getInfoAPI.dart';
import '../../../model/messageModel.dart';
import '../../../model/userInfoModel.dart';
import '../../../utils/gloabl.dart';

typedef CurrentUserLoader = Future<UserInfoModel> Function(String userName);

class FriendshipRealtimeService {
  const FriendshipRealtimeService({this.currentUserLoader = getUserInfoApi});

  final CurrentUserLoader currentUserLoader;

  Future<void> handle(Map<String, dynamic> event) async {
    if (event['type'] != 'friendRequestUpdated' ||
        event['action']?.toString() != 'accepted') {
      return;
    }

    final global = GlobalUtil();
    final currentUser = global.userName?.trim() ?? '';
    final applicant = event['fromUserId']?.toString().trim() ?? '';
    final acceptor = event['toUserId']?.toString().trim() ?? '';
    if (currentUser.isEmpty ||
        (currentUser != applicant && currentUser != acceptor)) {
      return;
    }
    final counterpart = currentUser == applicant ? acceptor : applicant;
    if (counterpart.isEmpty) return;

    _cacheMessage(
      global,
      counterpart,
      currentUser,
      event['verificationMessage'],
    );
    _cacheMessage(global, counterpart, currentUser, event['greeting']);

    try {
      global.userInfoModel = await currentUserLoader(currentUser);
    } catch (_) {
      // The regular friend-list refresh remains as a fallback when the
      // one-shot profile request is temporarily unavailable.
    } finally {
      // The relationship event itself is authoritative for the current page.
      // A transient profile refresh failure must not leave the composer locked.
      global.friendshipRevision.value++;
    }
  }

  void _cacheMessage(
    GlobalUtil global,
    String counterpart,
    String currentUser,
    dynamic rawMessage,
  ) {
    if (rawMessage is! Map) return;
    final data = Map<String, dynamic>.from(rawMessage);
    final messageId = int.tryParse(data['msgId']?.toString() ?? '');
    if (messageId == null || messageId <= 0) return;
    final senderId = data['sendUserId']?.toString().trim() ?? '';
    final timestamp =
        int.tryParse(data['sendTime']?.toString() ?? '') ??
        DateTime.now().millisecondsSinceEpoch;
    final isMe = senderId == currentUser;
    global.addMessage(
      counterpart,
      Message(
        msgId: messageId,
        content: data['msgContent']?.toString() ?? '',
        isMe: isMe,
        time: GlobalUtil.formatChatTimestamp(timestamp),
        isRead: true,
        conversationId:
            data['sessionId']?.toString() ??
            GlobalUtil.generateSessionId(currentUser, counterpart),
        status: isMe ? MessageStatus.sent : MessageStatus.read,
        senderId: senderId.isEmpty
            ? (isMe ? currentUser : counterpart)
            : senderId,
        timestamp: timestamp,
        isFriendVerification: isFriendVerificationExtendInfo(
          data['extendInfo'],
        ),
      ),
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/features/friends/application/friendship_realtime_service.dart';
import 'package:flutter_base/model/userInfoModel.dart';
import 'package:flutter_base/utils/gloabl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final global = GlobalUtil();
    global.resetSessionState();
    global.userName = '1001';
  });

  tearDown(() => GlobalUtil().resetSessionState());

  test(
    'accepted friendship refreshes cache and restores both starter messages',
    () async {
      final service = FriendshipRealtimeService(
        currentUserLoader: (_) async => UserInfoModel.formJSON({
          'userName': '1001',
          'friendListData': [
            {'userName': '1002', 'nickName': '新好友'},
          ],
        }),
      );
      final revisionBefore = GlobalUtil().friendshipRevision.value;

      await service.handle({
        'type': 'friendRequestUpdated',
        'action': 'accepted',
        'fromUserId': '1001',
        'toUserId': '1002',
        'verificationMessage': {
          'msgId': 501,
          'msgContent': '你好，我想加你为好友',
          'sendUserId': '1001',
          'sendTime': 1000,
          'sessionId': '1002_1001',
          'extendInfo': '{"kind":"friend_verification"}',
        },
        'greeting': {
          'msgId': 502,
          'msgContent': '我们已经成功添加好友啦!',
          'sendUserId': '1002',
          'sendTime': 1001,
          'sessionId': '1002_1001',
          'extendInfo': '{}',
        },
      });

      expect(GlobalUtil().hasFriend('1002'), isTrue);
      expect(GlobalUtil().friendshipRevision.value, revisionBefore + 1);
      final messages = GlobalUtil().getChatRecords('1002');
      expect(messages.map((message) => message.msgId), [501, 502]);
      expect(messages.first.isFriendVerification, isTrue);
      expect(messages.first.isMe, isTrue);
      expect(messages.last.isMe, isFalse);
    },
  );
}

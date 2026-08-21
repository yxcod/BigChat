import 'package:flutter_base/model/conversationModel.dart';
import 'package:flutter_base/model/friendInfoModel.dart';
import 'package:flutter_base/model/groupMessageModel.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('会话模型兼容数字字符串', () {
    final model = ConversationModel.formJSON({
      'convId': 88,
      'convType': '1',
      'user1Id': 10001,
      'user2Id': '10002',
      'groupId': 0,
      'lastMsgId': 99,
      'lastSenderId': 10001,
      'unreadCount': '3',
      'updateTime': '1700000000',
      'user2isValid': '1',
      'user1isVaild': 1,
    });

    expect(model.convId, '88');
    expect(model.unreadCount, 3);
    expect(model.updateTime, 1700000000000);
  });

  test('群消息及已读人员兼容字符串数字', () {
    final model = MessageDetailModel.fromJson({
      'msgId': '101',
      'groupId': '12',
      'senderId': 10086,
      'msgType': '1',
      'msgContent': '你好',
      'sendTime': '1700000000',
      'readers': [
        {'userId': 10010, 'readTime': '1700000010'},
      ],
    });

    expect(model.msgId, 101);
    expect(model.groupId, 12);
    expect(model.senderId, '10086');
    expect(model.sendTime, 1700000000000);
    expect(model.readers.single.userId, '10010');
    expect(model.readers.single.readTime, 1700000010000);
  });

  test('消息枚举越界时使用安全默认值', () {
    final model = MessageModel.fromJSON({
      'msgId': '7',
      'timestamp': '1700000000',
      'messageType': 999,
      'messageStatus': 'read',
    });

    expect(model.msgId, 7);
    expect(model.messageType, MessageType.text);
    expect(model.messageStatus, MessageStatus.read);
  });

  test('好友在线状态兼容数字和字符串', () {
    expect(FriendInfoModel.formJSON({'onlineStatus': '1'}).isOnline, isTrue);
    expect(FriendInfoModel.formJSON({'onlineStatus': 0}).isOnline, isFalse);
  });
}

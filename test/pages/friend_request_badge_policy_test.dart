import 'package:flutter_base/model/friendRequestModel.dart';
import 'package:flutter_base/pages/mainPages/friendsPage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('只有待处理的收到申请会计入新的朋友红点', () {
    final requests = [
      FriendRequestModel(
        requestId: 1,
        userName: 'incoming',
        nickName: '收到的申请',
        verificationMessage: '',
        requestTime: DateTime.now(),
        direction: FriendRequestDirection.incoming,
      ),
      FriendRequestModel(
        requestId: 2,
        userName: 'rejected',
        nickName: '被拒绝的申请',
        verificationMessage: '',
        requestTime: DateTime.now(),
        status: RequestStatus.rejected,
        direction: FriendRequestDirection.outgoing,
      ),
    ];

    expect(countUnseenIncomingFriendRequests(requests, <int>{}), 1);
    expect(countUnseenIncomingFriendRequests(requests, <int>{1}), 0);
  });
}

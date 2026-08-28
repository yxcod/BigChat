class PrivateDeliveryFailure {
  const PrivateDeliveryFailure._();

  static bool isNotFriends(Map<String, dynamic> payload) {
    final code = payload['errorCode']?.toString().trim();
    final reason = payload['reason']?.toString().trim();
    return code == 'not_friends' || reason == 'not_friends';
  }
}

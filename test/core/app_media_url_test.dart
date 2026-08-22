import 'package:flutter_base/core/media/app_media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String buildUrl(String ownerId, String imageName) =>
      'https://example.test/image/$ownerId/$imageName';

  test('group image filename is resolved with the sender as owner', () {
    final url = AppMediaUrl.resolveMessageImage(
      content: 'sender_group_1.jpg',
      senderId: 'sender',
      currentUserId: 'me',
      isMine: false,
      buildServerUrl: buildUrl,
    );

    expect(url, 'https://example.test/image/sender/sender_group_1.jpg');
  });

  test('existing remote image URL is preserved', () {
    const remoteUrl = 'https://cdn.example.test/image.jpg';
    final url = AppMediaUrl.resolveMessageImage(
      content: remoteUrl,
      senderId: 'sender',
      currentUserId: 'me',
      isMine: false,
      buildServerUrl: buildUrl,
    );

    expect(url, remoteUrl);
  });

  test('own legacy image falls back to current user as owner', () {
    final url = AppMediaUrl.resolveMessageImage(
      content: 'legacy.jpg',
      senderId: null,
      currentUserId: 'me',
      isMine: true,
      buildServerUrl: buildUrl,
    );

    expect(url, 'https://example.test/image/me/legacy.jpg');
  });
}

import 'package:flutter_base/core/cache/app_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated URLs for the same image share a stable cache key', () {
    const first =
        'http://server/api/image/download?key=token-a&userName=alice&imageName=head.jpg';
    const second =
        'http://server/api/image/download?key=token-b&userName=alice&imageName=head.jpg';

    expect(AppImageCache.cacheKey(first), AppImageCache.cacheKey(second));
  });

  test('a changed image file invalidates the previous cache key', () {
    const oldAvatar =
        'http://server/api/image/download?key=token&userName=alice&imageName=head-v1.jpg';
    const newAvatar =
        'http://server/api/image/download?key=token&userName=alice&imageName=head-v2.jpg';

    expect(
      AppImageCache.cacheKey(oldAvatar),
      isNot(AppImageCache.cacheKey(newAvatar)),
    );
  });

  test('external images retain their full URL as the cache identity', () {
    const url = 'https://images.example.com/photo.jpg?v=2';
    expect(AppImageCache.cacheKey(url), url);
  });
}

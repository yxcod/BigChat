import 'package:flutter_base/features/chat/data/hidden_conversations_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists hidden conversations per signed-in owner', () async {
    final storage = <String, String>{};
    final store = HiddenConversationsStore(
      readString: (key) => storage[key],
      writeString: (key, value) async => storage[key] = value,
    );

    await store.save('me', {'private:alice': 2000});

    expect(store.load('me'), {'private:alice': 2000});
    expect(store.load('other'), isEmpty);
  });

  test('a newer message makes a hidden conversation visible again', () {
    final store = HiddenConversationsStore(
      readString: (_) => null,
      writeString: (_, _) async {},
    );
    final hidden = {'group:7': 2000000};

    expect(store.shouldHide(hidden, 'group:7', 1999), isTrue);
    expect(store.shouldHide(hidden, 'group:7', 2001), isFalse);
  });
}

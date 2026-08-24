import 'package:flutter_base/features/chat/data/hidden_messages_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('locally hidden messages remain hidden after a store reload', () async {
    final values = <String, String>{};
    HiddenMessagesStore createStore() => HiddenMessagesStore(
      readString: (key) => values[key],
      writeString: (key, value) async => values[key] = value,
    );

    await createStore().hide('alice', 'group:12', 9876);

    final restored = createStore();
    expect(restored.isHidden('alice', 'group:12', 9876), isTrue);
    expect(restored.isHidden('bob', 'group:12', 9876), isFalse);
    expect(restored.isHidden('alice', 'group:13', 9876), isFalse);
  });

  test('invalid persisted values never hide valid messages', () {
    final store = HiddenMessagesStore(
      readString: (_) => '{broken-json',
      writeString: (_, _) async {},
    );

    expect(store.load('alice', 'bob'), isEmpty);
  });

  test('rapid local deletions are serialized without losing ids', () async {
    final values = <String, String>{};
    final store = HiddenMessagesStore(
      readString: (key) => values[key],
      writeString: (key, value) async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        values[key] = value;
      },
    );

    await Future.wait([
      store.hide('alice', 'bob', 1),
      store.hide('alice', 'bob', 2),
    ]);

    expect(store.load('alice', 'bob'), {1, 2});
  });
}

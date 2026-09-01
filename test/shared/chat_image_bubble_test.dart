import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_base/shared/widgets/chat_image_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chat image uses a neutral bounded placeholder before decoding', (
    tester,
  ) async {
    final provider = MemoryImage(Uint8List.fromList(const [0, 1, 2]));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatImageBubble(
            imageProvider: provider,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('chat_image_sized_container')),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('chat_image_sized_container'))),
      const Size(160, 120),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFE9ECEB));
  });
}

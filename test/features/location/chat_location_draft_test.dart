import 'package:flutter/widgets.dart';
import 'package:flutter_base/features/location/presentation/chat_location_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolved location replaces the existing draft without sending it', () {
    final controller = TextEditingController(text: '原有聊天内容');

    replaceChatDraftWithLocation(controller, '  北京市海淀区中关村  ');

    expect(controller.text, '北京市海淀区中关村');
    expect(controller.selection, const TextSelection.collapsed(offset: 9));
    controller.dispose();
  });
}

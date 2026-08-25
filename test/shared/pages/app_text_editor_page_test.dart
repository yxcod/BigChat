import 'package:flutter/material.dart';
import 'package:flutter_base/shared/pages/app_text_editor_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('统一文本编辑页使用紧凑保存按钮并返回编辑结果', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppTextEditorPage(
                    title: '编辑文本',
                    initialValue: '旧内容',
                    hintText: '请输入',
                    maxLength: 20,
                    fieldKey: Key('editor_field'),
                    saveButtonKey: Key('editor_save'),
                  ),
                ),
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.getSize(find.byKey(const Key('editor_save'))).height, 32);

    await tester.enterText(find.byKey(const Key('editor_field')), '新内容');
    await tester.tap(find.byKey(const Key('editor_save')));
    await tester.pumpAndSettle();
    expect(result, '新内容');
  });
}

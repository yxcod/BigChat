import 'package:flutter/material.dart';

class AppSelectableText extends StatelessWidget {
  const AppSelectableText(
    this.data, {
    super.key,
    this.style,
    this.onDelete,
    this.onQuote,
  });

  final String data;
  final TextStyle? style;
  final VoidCallback? onDelete;
  final VoidCallback? onQuote;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      data,
      style: style,
      contextMenuBuilder: (context, editableTextState) {
        final items = <ContextMenuButtonItem>[
          ...editableTextState.contextMenuButtonItems,
          if (onQuote != null)
            ContextMenuButtonItem(
              label: '引用',
              onPressed: () {
                editableTextState.hideToolbar();
                onQuote?.call();
              },
            ),
          if (onDelete != null)
            ContextMenuButtonItem(
              label: '删除',
              onPressed: () {
                editableTextState.hideToolbar();
                onDelete?.call();
              },
            ),
        ];
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: items,
        );
      },
    );
  }
}

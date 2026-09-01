import 'package:flutter/material.dart';

import '../../model/messageModel.dart';
import '../../app/theme/app_theme_context.dart';
import 'app_selectable_text.dart';

class QuotedMessageView extends StatelessWidget {
  const QuotedMessageView({
    super.key,
    required this.quote,
    this.compact = false,
  });

  final MessageQuote quote;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      margin: EdgeInsets.only(bottom: compact ? 0 : 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(7),
        border: const Border(
          left: BorderSide(color: Color(0xFF7A8793), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            quote.senderLabel.isEmpty ? quote.senderId : quote.senderLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.appTextPrimary.withValues(alpha: 0.82),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            quote.preview,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class QuoteComposerPreview extends StatelessWidget {
  const QuoteComposerPreview({
    super.key,
    required this.quote,
    required this.onClose,
  });

  final MessageQuote quote;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 9, right: 3, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: context.appSearchBackground,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Expanded(child: QuotedMessageView(quote: quote, compact: true)),
          IconButton(
            key: const ValueKey('cancel_message_quote'),
            tooltip: '取消引用',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: Icon(Icons.close, size: 18, color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }
}

class QuotedTextMessageBubble extends StatelessWidget {
  const QuotedTextMessageBubble({
    super.key,
    required this.quote,
    required this.text,
    required this.bubbleColor,
    required this.textColor,
    required this.borderRadius,
    this.maxWidth,
  });

  final MessageQuote quote;
  final String text;
  final Color bubbleColor;
  final Color textColor;
  final BorderRadius borderRadius;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('quoted_text_message_bubble'),
      constraints: BoxConstraints(maxWidth: maxWidth ?? 280),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
              border: Border(
                left: BorderSide(
                  color: textColor.withValues(alpha: 0.58),
                  width: 3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  quote.senderLabel.isEmpty
                      ? quote.senderId
                      : quote.senderLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  quote.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.74),
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AppSelectableText(
            text,
            style: TextStyle(color: textColor, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

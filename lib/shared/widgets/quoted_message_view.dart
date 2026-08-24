import 'package:flutter/material.dart';

import '../../model/messageModel.dart';

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
            style: const TextStyle(
              color: Color(0xFF52606D),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            quote.preview,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF65717C),
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
        color: const Color(0xFFF0F2F4),
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
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

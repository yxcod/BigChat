import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../data/merchant_reviews_repository.dart';
import '../domain/merchant_review.dart';

class MerchantReviewCommentsPage extends StatefulWidget {
  const MerchantReviewCommentsPage({
    super.key,
    required this.review,
    required this.repository,
  });

  final MerchantReview review;
  final MerchantReviewsRepository repository;

  @override
  State<MerchantReviewCommentsPage> createState() =>
      _MerchantReviewCommentsPageState();
}

class _MerchantReviewCommentsPageState
    extends State<MerchantReviewCommentsPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late MerchantReview _review;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _review = widget.review;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final updated = await widget.repository.addComment(
        _review.merchant.id,
        content,
      );
      if (!mounted) return;
      _controller.clear();
      _focusNode.requestFocus();
      setState(() {
        _review = updated;
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评论发送失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: context.appSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${_review.merchant.name} · 评论',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: context.appDivider),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildComments()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildComments() {
    if (_review.comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 42,
              color: context.appTextSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              '还没有评论，说说你的体验吧',
              style: TextStyle(color: context.appTextSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      itemCount: _review.comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final comment = _review.comments[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFE5F7ED),
              child: Text(
                '我',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  comment.content,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 14.5,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        color: context.appSurface,
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('merchant_review_comment_field'),
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '写下你的评论',
                  filled: true,
                  fillColor: context.appSearchBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 9),
            IconButton.filled(
              key: const ValueKey('merchant_review_send_comment'),
              onPressed: _controller.text.trim().isEmpty || _sending
                  ? null
                  : _send,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: context.appDivider,
              ),
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

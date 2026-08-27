import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../core/cache/app_image_cache.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import '../../../utils/gloabl.dart';
import '../data/merchant_review_image_uploader.dart';
import '../data/merchant_reviews_repository.dart';
import '../domain/merchant_review.dart';

typedef MerchantReviewCommentImageUrlBuilder =
    String Function(String userId, String imageName);

class MerchantReviewCommentsPage extends StatefulWidget {
  const MerchantReviewCommentsPage({
    super.key,
    required this.review,
    required this.repository,
    this.imageUploader,
    this.imageUrlBuilder,
  });

  final MerchantReview review;
  final MerchantReviewsRepository repository;
  final MerchantReviewImageUploader? imageUploader;
  final MerchantReviewCommentImageUrlBuilder? imageUrlBuilder;

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
  String? _selectedImagePath;
  late final MerchantReviewImageUploader _imageUploader;

  @override
  void initState() {
    super.initState();
    _review = widget.review;
    _imageUploader =
        widget.imageUploader ?? ServerMerchantReviewImageUploader();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    final selectedImagePath = _selectedImagePath;
    if ((content.isEmpty && selectedImagePath == null) || _sending) return;
    setState(() => _sending = true);
    try {
      var imageName = '';
      if (selectedImagePath != null) {
        final authorId = GlobalUtil().userName?.trim() ?? '';
        if (authorId.isEmpty) throw StateError('无法获取当前用户信息');
        imageName = await _imageUploader.upload(
          authorId: authorId,
          localPath: selectedImagePath,
        );
      }
      final updated = await widget.repository.addComment(
        _review.merchant.id,
        content,
        imageName: imageName,
      );
      if (!mounted) return;
      _controller.clear();
      _focusNode.requestFocus();
      setState(() {
        _review = updated;
        _selectedImagePath = null;
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

  Future<void> _pickImage() async {
    if (_sending) return;
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (image == null || !mounted) return;
    setState(() => _selectedImagePath = image.path);
  }

  ImageProvider<Object>? _commentImageProvider(MerchantReviewComment comment) {
    if (comment.imageName.trim().isEmpty || comment.userId.trim().isEmpty) {
      return null;
    }
    try {
      final url =
          widget.imageUrlBuilder?.call(comment.userId, comment.imageName) ??
          GlobalUtil().getImageURL(comment.userId, comment.imageName);
      return AppImageCache.provider(url);
    } catch (_) {
      return null;
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
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE5F7ED),
              child: Text(
                comment.displayName.trim().isEmpty
                    ? '用户'
                    : comment.displayName.trim().characters.first,
                style: const TextStyle(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (comment.displayName.trim().isNotEmpty)
                      Text(
                        comment.displayName,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (comment.displayName.trim().isNotEmpty &&
                        comment.content.isNotEmpty)
                      const SizedBox(height: 4),
                    if (comment.content.isNotEmpty)
                      Text(
                        comment.content,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                    if (_commentImageProvider(comment)
                        case final provider?) ...[
                      if (comment.content.isNotEmpty) const SizedBox(height: 9),
                      _CommentThumbnail(
                        key: ValueKey('merchant_comment_image_${comment.id}'),
                        imageProvider: provider,
                        heroTag: 'merchant-comment-image-${comment.id}',
                      ),
                    ],
                  ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedImagePath case final path?) ...[
              _SelectedCommentImage(
                path: path,
                onRemove: _sending
                    ? null
                    : () => setState(() => _selectedImagePath = null),
              ),
              const SizedBox(height: 9),
            ],
            Row(
              children: [
                IconButton(
                  key: const ValueKey('merchant_review_pick_image'),
                  onPressed: _sending ? null : _pickImage,
                  tooltip: '添加图片',
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
                const SizedBox(width: 4),
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
                  onPressed:
                      (_controller.text.trim().isEmpty &&
                              _selectedImagePath == null) ||
                          _sending
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
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentThumbnail extends StatelessWidget {
  const _CommentThumbnail({
    super.key,
    required this.imageProvider,
    required this.heroTag,
  });

  final ImageProvider<Object> imageProvider;
  final Object heroTag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showFullscreenImage(
        context,
        imageProvider: imageProvider,
        heroTag: heroTag,
      ),
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox.square(
            dimension: 92,
            child: Image(
              image: imageProvider,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFEDEDED),
                child: Icon(Icons.broken_image_outlined, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedCommentImage extends StatelessWidget {
  const _SelectedCommentImage({required this.path, required this.onRemove});

  final String path;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final provider = FileImage(File(path));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          key: const ValueKey('merchant_review_selected_image'),
          onTap: () => showFullscreenImage(context, imageProvider: provider),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox.square(
              dimension: 72,
              child: Image(image: provider, fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          right: -8,
          top: -8,
          child: IconButton.filled(
            key: const ValueKey('merchant_review_remove_selected_image'),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 24, height: 24),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xCC333333),
            ),
            icon: const Icon(Icons.close_rounded, size: 16),
          ),
        ),
      ],
    );
  }
}

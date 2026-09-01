import 'dart:math' as math;

import 'package:flutter/material.dart';

class ChatImageBubble extends StatefulWidget {
  const ChatImageBubble({
    super.key,
    required this.imageProvider,
    required this.borderRadius,
    this.maxWidth = 200,
    this.maxHeight = 200,
  });

  final ImageProvider imageProvider;
  final BorderRadius borderRadius;
  final double maxWidth;
  final double maxHeight;

  @override
  State<ChatImageBubble> createState() => _ChatImageBubbleState();
}

class _ChatImageBubbleState extends State<ChatImageBubble> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ChatImageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) _resolve();
  }

  void _resolve() {
    final stream = widget.imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    if (_stream?.key == stream.key) return;
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _imageSize = null;
    _stream = stream;
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (size.width > 0 && size.height > 0) {
        setState(() => _imageSize = size);
      }
    }, onError: (_, _) {});
    stream.addListener(_listener!);
  }

  Size get _displaySize {
    final source = _imageSize;
    if (source == null) return const Size(160, 120);
    final scale = math.min(
      widget.maxWidth / source.width,
      widget.maxHeight / source.height,
    );
    final width = source.width * scale;
    final height = source.height * scale;
    return Size(width, height);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _displaySize;
    return AnimatedContainer(
      key: const ValueKey('chat_image_sized_container'),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: size.width,
      height: size.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEB),
        borderRadius: widget.borderRadius,
      ),
      child: Image(
        image: widget.imageProvider,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, synchronouslyLoaded) {
          if (synchronouslyLoaded || frame != null) return child;
          return const Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      ),
    );
  }
}

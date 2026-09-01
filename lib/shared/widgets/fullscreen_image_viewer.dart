import 'package:flutter/material.dart';

Future<void> showFullscreenImage(
  BuildContext context, {
  required ImageProvider imageProvider,
  Object? heroTag,
  Future<void> Function()? onSave,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, _, _) => FullscreenImageViewer(
        imageProvider: imageProvider,
        heroTag: heroTag,
        onSave: onSave,
      ),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

class FullscreenImageViewer extends StatelessWidget {
  const FullscreenImageViewer({
    super.key,
    required this.imageProvider,
    this.heroTag,
    this.onSave,
  });

  final ImageProvider imageProvider;
  final Object? heroTag;
  final Future<void> Function()? onSave;

  Future<void> _showActions(BuildContext context) async {
    if (onSave == null) return;
    final action = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('save_fullscreen_image'),
              leading: const Icon(Icons.download_rounded),
              title: const Text('保存到本地'),
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == true && context.mounted) await onSave?.call();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: imageProvider,
      fit: BoxFit.contain,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
      errorBuilder: (_, _, _) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 52,
        ),
      ),
    );

    return ColoredBox(
      key: const ValueKey('fullscreen_image_viewer'),
      color: Colors.black,
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).maybePop(),
          onLongPress: () => _showActions(context),
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            boundaryMargin: const EdgeInsets.all(80),
            clipBehavior: Clip.none,
            child: SizedBox.expand(
              child: Center(
                child: heroTag == null
                    ? image
                    : Hero(tag: heroTag!, child: image),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

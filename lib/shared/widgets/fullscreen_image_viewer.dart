import 'package:flutter/material.dart';

Future<void> showFullscreenImage(
  BuildContext context, {
  required ImageProvider imageProvider,
  Object? heroTag,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, _, _) =>
          FullscreenImageViewer(imageProvider: imageProvider, heroTag: heroTag),
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
  });

  final ImageProvider imageProvider;
  final Object? heroTag;

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

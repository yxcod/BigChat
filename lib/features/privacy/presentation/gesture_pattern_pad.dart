import 'dart:math' as math;

import 'package:flutter/material.dart';

class GesturePatternPad extends StatefulWidget {
  const GesturePatternPad({
    super.key,
    required this.onCompleted,
    this.enabled = true,
  });

  final ValueChanged<List<int>> onCompleted;
  final bool enabled;

  @override
  State<GesturePatternPad> createState() => _GesturePatternPadState();
}

class _GesturePatternPadState extends State<GesturePatternPad> {
  final List<int> _selected = [];
  Offset? _pointer;

  void _update(Offset position, Size size) {
    if (!widget.enabled) return;
    final points = _points(size);
    var nearest = -1;
    var distance = double.infinity;
    for (var index = 0; index < points.length; index++) {
      final candidate = (points[index] - position).distance;
      if (candidate < distance) {
        nearest = index;
        distance = candidate;
      }
    }
    if (nearest >= 0 &&
        distance <= size.width / 8 &&
        !_selected.contains(nearest)) {
      setState(() => _selected.add(nearest));
    } else {
      setState(() => _pointer = position);
    }
  }

  void _complete() {
    if (_selected.isNotEmpty) widget.onCompleted(List<int>.of(_selected));
    setState(() {
      _selected.clear();
      _pointer = null;
    });
  }

  List<Offset> _points(Size size) {
    final step = size.width / 3;
    return [
      for (var row = 0; row < 3; row++)
        for (var column = 0; column < 3; column++)
          Offset(step * (column + .5), step * (row + .5)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size.square(constraints.maxWidth);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _update(details.localPosition, size),
            onPanUpdate: (details) => _update(details.localPosition, size),
            onPanEnd: (_) => _complete(),
            child: CustomPaint(
              painter: _GesturePatternPainter(
                points: _points(size),
                selected: _selected,
                pointer: _pointer,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GesturePatternPainter extends CustomPainter {
  const _GesturePatternPainter({
    required this.points,
    required this.selected,
    required this.pointer,
    required this.color,
  });

  final List<Offset> points;
  final List<int> selected;
  final Offset? pointer;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: .65)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (selected.isNotEmpty) {
      final path = Path()
        ..moveTo(points[selected.first].dx, points[selected.first].dy);
      for (final index in selected.skip(1)) {
        path.lineTo(points[index].dx, points[index].dy);
      }
      if (pointer != null) path.lineTo(pointer!.dx, pointer!.dy);
      canvas.drawPath(path, line);
    }
    for (var index = 0; index < points.length; index++) {
      final active = selected.contains(index);
      canvas.drawCircle(
        points[index],
        math.max(9, size.width / 32),
        Paint()
          ..color = active ? color : color.withValues(alpha: .12)
          ..style = active ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GesturePatternPainter oldDelegate) => true;
}

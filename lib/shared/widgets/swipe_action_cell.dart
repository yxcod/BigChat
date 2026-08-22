import 'package:flutter/material.dart';

class SwipeActionCell extends StatefulWidget {
  const SwipeActionCell({
    super.key,
    required this.child,
    required this.onDelete,
    this.deleteLabel = '删除',
    this.actionExtent = 76,
  });

  final Widget child;
  final VoidCallback onDelete;
  final String deleteLabel;
  final double actionExtent;

  @override
  State<SwipeActionCell> createState() => _SwipeActionCellState();
}

class _SwipeActionCellState extends State<SwipeActionCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _offset = 0;

  bool get _isOpen => _offset < -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() => setState(() => _offset = _animation.value));
    _animation = const AlwaysStoppedAnimation(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _controller.stop();
    _animation = Tween<double>(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward(from: 0);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _controller.stop();
    setState(() {
      _offset = (_offset + details.delta.dx).clamp(-widget.actionExtent, 0.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final shouldOpen =
        details.primaryVelocity != null && details.primaryVelocity! < -250
        ? true
        : details.primaryVelocity != null && details.primaryVelocity! > 250
        ? false
        : _offset.abs() >= widget.actionExtent * 0.42;
    _animateTo(shouldOpen ? -widget.actionExtent : 0);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: widget.actionExtent,
                child: Material(
                  color: const Color(0xFFE53935),
                  child: InkWell(
                    key: const ValueKey('swipe_delete_action'),
                    onTap: widget.onDelete,
                    child: Center(
                      child: Text(
                        widget.deleteLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_offset, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              onTap: _isOpen ? () => _animateTo(0) : null,
              child: AbsorbPointer(absorbing: _isOpen, child: widget.child),
            ),
          ),
        ],
      ),
    );
  }
}

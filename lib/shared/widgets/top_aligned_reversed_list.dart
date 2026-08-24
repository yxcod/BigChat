import 'package:flutter/material.dart';

/// Keeps a reversed chat list at the top when it contains only a few items.
/// Larger histories retain the regular lazy reversed viewport so the newest
/// message is visible on the first frame without building the whole history.
class TopAlignedReversedList extends StatelessWidget {
  const TopAlignedReversedList({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.sparseItemLimit = 12,
  });

  final ScrollController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final int sparseItemLimit;

  @override
  Widget build(BuildContext context) {
    Widget buildList({required bool shrinkWrap}) => ListView.builder(
      controller: controller,
      padding: padding,
      reverse: true,
      shrinkWrap: shrinkWrap,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );

    if (itemCount > sparseItemLimit) {
      return buildList(shrinkWrap: false);
    }
    return Align(
      alignment: Alignment.topCenter,
      child: buildList(shrinkWrap: true),
    );
  }
}

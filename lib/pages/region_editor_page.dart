import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_theme_context.dart';
import '../features/location/data/app_location_service.dart';

typedef CityLocator = Future<String> Function();

class RegionEditorPage extends StatefulWidget {
  const RegionEditorPage({
    super.key,
    required this.initialRegion,
    this.cityLocator,
  });

  final String initialRegion;
  final CityLocator? cityLocator;

  @override
  State<RegionEditorPage> createState() => _RegionEditorPageState();
}

class _RegionEditorPageState extends State<RegionEditorPage> {
  late final TextEditingController _controller;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialRegion,
    )..selection = TextSelection.collapsed(offset: widget.initialRegion.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> _locateCity() async {
    final place = await AppLocationService().locate(
      upload: false,
      timeout: const Duration(seconds: 10),
    );
    return place.cityRegion.isEmpty ? place.address : place.cityRegion;
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final region = await (widget.cityLocator ?? _locateCity)();
      if (!mounted) return;
      if (region.trim().isEmpty) throw Exception('未解析到市级地区');
      setState(() {
        _controller.text = region.trim();
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('定位失败：$error，请手动填写地区')));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _complete() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写市级地区')));
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: context.appSurface,
        surfaceTintColor: context.appSurface,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 76,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            '取消',
            style: TextStyle(color: context.appTextPrimary, fontSize: 16),
          ),
        ),
        title: const Text('设置地区'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: UnconstrainedBox(
              child: SizedBox(
                height: 32,
                child: FilledButton(
                  key: const Key('region_complete_button'),
                  onPressed: _complete,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: const Text(
                    '保存',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: context.appSurface,
            child: InkWell(
              key: const Key('use_current_location_button'),
              onTap: _isLocating ? null : _useCurrentLocation,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.my_location,
                      color: AppColors.primary,
                      size: 21,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('使用当前位置', style: TextStyle(fontSize: 16)),
                    ),
                    if (_isLocating)
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ColoredBox(
            color: context.appSurface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: TextField(
                key: const Key('region_manual_field'),
                controller: _controller,
                autofocus: false,
                maxLength: 100,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _complete(),
                decoration: const InputDecoration(
                  hintText: '手动填写，例如：山东省 济南市',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              '地区信息精确到市即可，不会保存具体街道位置。',
              style: TextStyle(color: context.appTextSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

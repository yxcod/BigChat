import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../location/data/nearby_places_service.dart';
import '../../location/domain/nearby_place.dart';

typedef NearbyPlacesLoader = Future<NearbyPlacesResult> Function();

class MomentLocationPickerPage extends StatefulWidget {
  const MomentLocationPickerPage({
    super.key,
    this.selectedLocation,
    this.loader,
  });

  final String? selectedLocation;
  final NearbyPlacesLoader? loader;

  @override
  State<MomentLocationPickerPage> createState() =>
      _MomentLocationPickerPageState();
}

class _MomentLocationPickerPageState extends State<MomentLocationPickerPage> {
  final TextEditingController _searchController = TextEditingController();
  NearbyPlacesResult? _result;
  Object? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final result = await (widget.loader ?? NearbyPlacesService().load)();
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  List<NearbyPlace> get _filteredPlaces {
    final places = _result?.places ?? const <NearbyPlace>[];
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return places;
    return places
        .where(
          (place) =>
              place.name.toLowerCase().contains(query) ||
              place.address.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  void _select(String value) => Navigator.of(context).pop(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        leadingWidth: 68,
        leading: TextButton(
          onPressed: () => Navigator.maybePop(context),
          child: const Text('取消'),
        ),
        title: const Text(
          '所在位置',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: context.appSurface,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: TextField(
              key: const Key('moment_location_search_field'),
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索附近位置',
                prefixIcon: const Icon(Icons.search, size: 21),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.cancel, size: 18),
                      ),
                filled: true,
                fillColor: context.appSearchBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      final message = _error.toString().replaceFirst('Exception: ', '').trim();
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              color: AppColors.primary,
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(message.isEmpty ? '位置获取失败' : message),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('重新获取')),
          ],
        ),
      );
    }
    if (_result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final city = _result!.currentCity;
    final cityMatches =
        _query.trim().isEmpty ||
        city.toLowerCase().contains(_query.toLowerCase());
    final places = _filteredPlaces;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _LocationTile(
          key: const Key('hide_moment_location'),
          name: '不显示位置',
          selected: widget.selectedLocation == null,
          accent: true,
          onTap: () => _select(''),
        ),
        if (cityMatches)
          _LocationTile(
            key: const Key('current_city_location'),
            name: city,
            subtitle: '当前城市',
            selected: widget.selectedLocation == city,
            onTap: () => _select(city),
          ),
        ...places.map(
          (place) => _LocationTile(
            key: ValueKey('nearby-place-${place.name}'),
            name: place.name,
            subtitle: _placeSubtitle(place),
            selected: widget.selectedLocation == place.name,
            onTap: () => _select(place.name),
          ),
        ),
        if (!cityMatches && places.isEmpty)
          Padding(
            padding: const EdgeInsets.all(36),
            child: Center(
              child: Text(
                '没有匹配的位置',
                style: TextStyle(color: context.appTextSecondary),
              ),
            ),
          ),
      ],
    );
  }

  String _placeSubtitle(NearbyPlace place) {
    final distance = place.distanceMeters;
    final distanceText = distance == null
        ? ''
        : distance < 1000
        ? '${distance}m'
        : '${(distance / 1000).toStringAsFixed(1)}km';
    if (distanceText.isEmpty) return place.address;
    if (place.address.isEmpty) return distanceText;
    return '$distanceText  |  ${place.address}';
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    super.key,
    required this.name,
    required this.onTap,
    this.subtitle = '',
    this.selected = false,
    this.accent = false,
  });

  final String name;
  final String subtitle;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.appDivider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: accent
                            ? AppColors.primary
                            : context.appTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

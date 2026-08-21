import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.query,
    required this.hintText,
    required this.onChanged,
    this.height = 44,
  });

  final TextEditingController controller;
  final String query;
  final String hintText;
  final ValueChanged<String> onChanged;
  final double height;

  void _clear() {
    controller.clear();
    onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          isDense: true,
          filled: true,
          fillColor: AppColors.searchBackground,
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.cancel,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: _clear,
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 40),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(height / 2),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(height / 2),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(height / 2),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
        ),
      ),
    );
  }
}

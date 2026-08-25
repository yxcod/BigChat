import 'package:flutter/widgets.dart';

/// Replaces any existing chat draft with a resolved address and keeps the
/// caret at the end so the user can edit or manually send it.
void replaceChatDraftWithLocation(
  TextEditingController controller,
  String address,
) {
  final locationText = address.trim();
  controller.value = TextEditingValue(
    text: locationText,
    selection: TextSelection.collapsed(offset: locationText.length),
  );
}

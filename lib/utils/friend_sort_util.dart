import 'package:pinyin/pinyin.dart';

class FriendSortUtil {
  const FriendSortUtil._();

  static String initial({
    required String displayName,
    required String userName,
  }) {
    final initial = _sortKey(displayName, userName).initial;
    return RegExp(r'[A-Z]').hasMatch(initial) ? initial : '#';
  }

  static int compare({
    required bool leftOnline,
    required String leftDisplayName,
    required String leftUserName,
    required bool rightOnline,
    required String rightDisplayName,
    required String rightUserName,
  }) {
    if (leftOnline != rightOnline) return leftOnline ? -1 : 1;

    final leftKey = _sortKey(leftDisplayName, leftUserName);
    final rightKey = _sortKey(rightDisplayName, rightUserName);
    final byCategory = leftKey.category.compareTo(rightKey.category);
    if (byCategory != 0) return byCategory;
    final byInitial = leftKey.initial.compareTo(rightKey.initial);
    if (byInitial != 0) return byInitial;
    final byPinyin = leftKey.pinyin.compareTo(rightKey.pinyin);
    if (byPinyin != 0) return byPinyin;
    return leftUserName.toLowerCase().compareTo(rightUserName.toLowerCase());
  }

  static _FriendSortKey _sortKey(String displayName, String userName) {
    final source = displayName.trim().isEmpty
        ? userName.trim()
        : displayName.trim();
    final pinyin = PinyinHelper.getPinyinE(
      source,
      separator: '',
      defPinyin: '#',
      format: PinyinFormat.WITHOUT_TONE,
    ).toUpperCase();
    final initial = pinyin.isEmpty ? '#' : pinyin.substring(0, 1);
    final category = RegExp(r'[A-Z]').hasMatch(initial)
        ? 0
        : RegExp(r'[0-9]').hasMatch(initial)
        ? 1
        : 2;
    return _FriendSortKey(category: category, initial: initial, pinyin: pinyin);
  }
}

class _FriendSortKey {
  const _FriendSortKey({
    required this.category,
    required this.initial,
    required this.pinyin,
  });

  final int category;
  final String initial;
  final String pinyin;
}

import 'package:flutter/material.dart';

/// 用于全局访问Navigator的工具类
class GlobalNavigatorKey {
  // 静态全局Key，用于访问Navigator
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // 获取NavigatorState
  static NavigatorState? get navigatorState {
    return navigatorKey.currentState;
  }

  // 获取BuildContext
  static BuildContext? get context {
    return navigatorKey.currentContext;
  }
}

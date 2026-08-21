import 'dart:async';

import 'package:flutter/material.dart';
import './routes/routeIndex.dart';
import './utils/storageUtil.dart';
import './utils/GlobalNavigatorKey.dart';
import './core/config/app_config.dart';
import './app/theme/app_theme.dart';
import './utils/gloabl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  await StorageUtil.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 移除应用生命周期监听
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 监听多个可能表示应用即将关闭的状态
    switch (state) {
      case AppLifecycleState.paused:
        // 应用进入后台
        debugPrint('应用进入后台');
        unawaited(GlobalUtil().flushChatRecordsToLocal());
        break;
      case AppLifecycleState.inactive:
        // 应用变为非活动状态
        debugPrint('应用变为非活动状态');
        break;
      case AppLifecycleState.detached:
        // 应用即将被销毁
        debugPrint('应用即将被销毁');

        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "全信",
      theme: AppTheme.light,
      navigatorKey: GlobalNavigatorKey.navigatorKey,
      initialRoute: '/login',
      routes: getRoutes(),
      onGenerateRoute: generateRoute,
    );
  }
}

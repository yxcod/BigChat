package com.example.flutter_base

import android.content.pm.PackageManager
import android.util.Log
import com.baidu.mapapi.CoordType
import com.baidu.mapapi.SDKInitializer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var baiduSdkInitialized = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.yxcod.bigchat/baidu_lbs_setup",
        ).setMethodCallHandler { call, result ->
            if (call.method != "initialize") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val applicationInfo = packageManager.getApplicationInfo(
                packageName,
                PackageManager.GET_META_DATA,
            )
            val apiKey = applicationInfo.metaData
                ?.getString("com.baidu.lbsapi.API_KEY")
                ?.trim()
                .orEmpty()
            if (apiKey.isEmpty()) {
                result.success(false)
                return@setMethodCallHandler
            }
            try {
                if (!baiduSdkInitialized) {
                    SDKInitializer.setAgreePrivacy(applicationContext, true)
                    SDKInitializer.setCoordType(CoordType.BD09LL)
                    SDKInitializer.initialize(applicationContext)
                    baiduSdkInitialized = true
                    Log.i(
                        "QuanxinBaiduLbs",
                        "Baidu SDK initialized for package=$packageName",
                    )
                }
                result.success(true)
            } catch (error: Exception) {
                Log.e("QuanxinBaiduLbs", "Baidu SDK initialization failed", error)
                result.success(false)
            }
        }
    }
}

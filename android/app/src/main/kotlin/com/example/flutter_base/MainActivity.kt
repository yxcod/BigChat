package com.example.flutter_base

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.baidu.mapapi.CoordType
import com.baidu.mapapi.SDKInitializer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.net.URLConnection
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var baiduSdkInitialized = false
    private var pendingFileExportResult: MethodChannel.Result? = null
    private var pendingFileExportSource: File? = null
    private val fileExportExecutor = Executors.newSingleThreadExecutor()

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FILE_EXPORT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingFileExportResult != null) {
                result.error("export_in_progress", "另一个文件正在保存", null)
                return@setMethodCallHandler
            }
            val sourcePath = call.argument<String>("sourcePath").orEmpty()
            val fileName = call.argument<String>("fileName")
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?: "聊天文件"
            val source = File(sourcePath)
            if (!source.isFile || source.length() <= 0L) {
                result.error("invalid_source", "待保存文件不存在", null)
                return@setMethodCallHandler
            }

            pendingFileExportResult = result
            pendingFileExportSource = source
            val mimeType = URLConnection.guessContentTypeFromName(fileName)
                ?: "application/octet-stream"
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mimeType
                putExtra(Intent.EXTRA_TITLE, fileName)
            }
            try {
                startActivityForResult(intent, FILE_EXPORT_REQUEST_CODE)
            } catch (error: Exception) {
                clearPendingFileExport()
                result.error("picker_unavailable", "无法打开系统文件选择器", error.message)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != FILE_EXPORT_REQUEST_CODE) return

        val callback = pendingFileExportResult ?: return
        val source = pendingFileExportSource
        val destination = data?.data
        if (resultCode != Activity.RESULT_OK || destination == null || source == null) {
            clearPendingFileExport()
            callback.success(false)
            return
        }

        fileExportExecutor.execute {
            try {
                copyFileToDocument(source, destination)
                Handler(Looper.getMainLooper()).post {
                    if (pendingFileExportResult !== callback) return@post
                    clearPendingFileExport()
                    callback.success(true)
                }
            } catch (error: Exception) {
                Log.e("QuanxinFileExport", "File export failed", error)
                Handler(Looper.getMainLooper()).post {
                    if (pendingFileExportResult !== callback) return@post
                    clearPendingFileExport()
                    callback.error("export_failed", "文件保存失败", error.message)
                }
            }
        }
    }

    private fun copyFileToDocument(source: File, destination: Uri) {
        val output = contentResolver.openOutputStream(destination, "w")
            ?: throw IllegalStateException("无法写入所选位置")
        FileInputStream(source).use { input ->
            output.use { target -> input.copyTo(target, DEFAULT_BUFFER_SIZE) }
        }
    }

    private fun clearPendingFileExport() {
        pendingFileExportResult = null
        pendingFileExportSource = null
    }

    override fun onDestroy() {
        pendingFileExportResult?.error("activity_destroyed", "文件保存已中断", null)
        clearPendingFileExport()
        fileExportExecutor.shutdownNow()
        super.onDestroy()
    }

    companion object {
        private const val FILE_EXPORT_CHANNEL = "com.yxcod.bigchat/file_export"
        private const val FILE_EXPORT_REQUEST_CODE = 7812
    }
}

package com.example.flutter_base

import android.app.Application
import com.baidu.mapapi.base.BmfMapApplication

class QuanxinApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // The Flutter Baidu plugin requires this context for its privacy
        // channel. SDK initialization is intentionally deferred until the
        // nearby feature is used, so privacy consent always happens first.
        BmfMapApplication.mContext = applicationContext
    }
}

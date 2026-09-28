package com.example.e09_elearning

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.e09_elearning/app_info")
            .setMethodCallHandler { call, result ->
                if (call.method != "getVersionName") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val packageInfo = packageManager.getPackageInfo(packageName, 0)
                result.success(packageInfo.versionName)
            }
    }
}

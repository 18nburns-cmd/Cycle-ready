package com.cycleready.app

import android.os.StatFs
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cycle_ready/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "freeStorageBytes") {
                    val stats = StatFs(filesDir.absolutePath)
                    result.success(stats.availableBytes)
                } else {
                    result.notImplemented()
                }
            }
    }
}

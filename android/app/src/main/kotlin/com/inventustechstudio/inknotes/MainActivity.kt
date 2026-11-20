package com.inventustechstudio.inknotes

import android.view.WindowManager
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "inknotes/security"
    private var widgetChannel: MethodChannel? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra("noteAction")?.let {
            widgetChannel?.invokeMethod("openNote", it)
            intent.removeExtra("noteAction")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "inknotes/widget")
        widgetChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "refresh" -> { NotesWidgetProvider.refresh(this); result.success(null) }
                "initialAction" -> {
                    result.success(intent.getStringExtra("noteAction"))
                    intent.removeExtra("noteAction")
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecureScreen") {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                    }
                    result.success(null)
                    NotesWidgetProvider.refresh(this)
                } else {
                    result.notImplemented()
                }
            }
    }
}

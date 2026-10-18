package dev.iamngoni.porthole

import android.content.Intent
import android.graphics.Rect
import android.net.Uri
import android.provider.Settings
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var claimsEdges = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Keep-awake and the back gesture, for lib/client/system.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.iamngoni.porthole/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "keepAwake" -> {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                "claimEdges" -> {
                    claimsEdges = call.arguments == true
                    applyEdgeClaim()
                    result.success(null)
                }
                "watchLocalNetwork" -> result.success(null)
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        window.decorView.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> applyEdgeClaim() }
    }

    /// Android lets an app keep up to 200dp of each side edge from the back gesture.
    private fun applyEdgeClaim() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val view = window.decorView
        if (!claimsEdges || view.width == 0) {
            view.systemGestureExclusionRects = emptyList()
            return
        }
        val density = resources.displayMetrics.density
        val tall = (200 * density).toInt().coerceAtMost(view.height)
        val wide = (32 * density).toInt()
        val top = (view.height - tall) / 2
        view.systemGestureExclusionRects = listOf(
            Rect(0, top, wide, top + tall),
            Rect(view.width - wide, top, view.width, top + tall),
        )
    }
}

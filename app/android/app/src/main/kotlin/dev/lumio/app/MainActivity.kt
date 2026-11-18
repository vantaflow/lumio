package dev.lumio.app

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Espace libre du volume qui porte un dossier (politique de cache torrents).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.lumio.app/storage")
            .setMethodCallHandler { call, result ->
                if (call.method != "freeBytes") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "path manquant", null)
                    return@setMethodCallHandler
                }
                try {
                    result.success(StatFs(path).availableBytes)
                } catch (e: Exception) {
                    result.error("statfs", e.message, null)
                }
            }
    }
}

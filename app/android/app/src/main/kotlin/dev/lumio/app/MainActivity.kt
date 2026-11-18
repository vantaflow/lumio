package dev.lumio.app

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Lien reçu (VIEW stremio:// / lumio://, ou texte partagé) : transmis à
    // Dart, qui ouvre l'écran d'ajout prérempli. Rien n'est installé ici.
    private var pendingLink: String? = null
    private var linksChannel: MethodChannel? = null

    private fun extractLink(intent: Intent?): String? = when (intent?.action) {
        Intent.ACTION_VIEW -> intent.dataString
        Intent.ACTION_SEND ->
            if (intent.type == "text/plain") intent.getStringExtra(Intent.EXTRA_TEXT) else null
        else -> null
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Pas de rejeu du lien quand l'activité est recréée (rotation...).
        if (savedInstanceState == null) pendingLink = extractLink(intent)
        setIntent(Intent())
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val link = extractLink(intent) ?: return
        setIntent(Intent())
        // Si Dart n'écoute pas encore (profil pas choisi), le lien reste en
        // attente et sera repris par takeLink.
        pendingLink = link
        linksChannel?.invokeMethod("link", link, object : MethodChannel.Result {
            override fun success(r: Any?) { if (r == true && pendingLink == link) pendingLink = null }
            override fun error(c: String, m: String?, d: Any?) {}
            override fun notImplemented() {}
        })
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        linksChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.lumio.app/links")
        linksChannel!!.setMethodCallHandler { call, result ->
            if (call.method == "takeLink") {
                result.success(pendingLink)
                pendingLink = null
            } else {
                result.notImplemented()
            }
        }
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
        // Un VPN est-il actif ? (les interfaces VPN ne sont pas toujours
        // visibles de Dart ; le nom de l'interface reste inconnu.)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.lumio.app/network")
            .setMethodCallHandler { call, result ->
                if (call.method != "vpnActive") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    val active = cm.allNetworks.any { n ->
                        cm.getNetworkCapabilities(n)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
                    }
                    result.success(active)
                } catch (e: Exception) {
                    result.error("network", e.message, null)
                }
            }
    }
}

package dev.lumio.app

import android.content.Context
import android.util.Log
import java.io.File
import java.net.InetAddress
import java.net.ServerSocket
import java.security.SecureRandom

/**
 * Cycle de vie du processus TorrServer (binaire officiel livré comme
 * libtorrserver.so, exécuté depuis nativeLibraryDir).
 *
 * Sécurité : le serveur web n'écoute que sur 127.0.0.1, sur un port libre
 * choisi à chaque lancement, et exige une authentification HTTP (mot de passe
 * aléatoire de 256 bits, écrit dans le dossier privé de l'application).
 * Ni la sortie du processus (pairs, adresses) ni le mot de passe ne sont
 * journalisés.
 */
class TorrServerManager(private val ctx: Context) {
    data class Endpoint(val port: Int, val user: String, val password: String)

    private val tag = "TorrServer"
    private val lock = Any()
    private var process: Process? = null
    private var endpoint: Endpoint? = null
    private var wanted = false
    private val restarts = ArrayDeque<Long>()

    private val dir: File get() = File(ctx.filesDir, "torrserver")
    private val pidFile: File get() = File(dir, "ts.pid")
    private val exe: File get() = File(ctx.applicationInfo.nativeLibraryDir, "libtorrserver.so")

    fun start(): Endpoint = synchronized(lock) {
        wanted = true
        val running = process
        val ep = endpoint
        if (running != null && running.isAlive && ep != null) return ep
        if (!exe.exists()) throw IllegalStateException("moteur absent pour cette architecture")
        dir.mkdirs()
        killOrphan()
        val fresh = Endpoint(freePort(), "lumio", randomSecret())
        spawn(fresh)
        endpoint = fresh
        fresh
    }

    /** Arrête le processus (SIGTERM, puis SIGKILL après 3 s). */
    fun stop() {
        val p: Process?
        synchronized(lock) {
            wanted = false
            p = process
            process = null
            endpoint = null
            restarts.clear()
        }
        if (p != null) {
            p.destroy()
            try {
                if (!p.waitFor(3, java.util.concurrent.TimeUnit.SECONDS)) p.destroyForcibly()
            } catch (e: InterruptedException) {
                p.destroyForcibly()
            }
        }
        pidFile.delete()
    }

    fun isAlive(): Boolean = synchronized(lock) { process?.isAlive == true }

    private fun spawn(ep: Endpoint) {
        // Mot de passe lisible par l'application seule.
        val accs = File(dir, "accs.db")
        accs.writeText("{\"${ep.user}\":\"${ep.password}\"}")
        accs.setReadable(false, false)
        accs.setReadable(true, true)
        accs.setWritable(false, false)
        accs.setWritable(true, true)
        val pb = ProcessBuilder(
            exe.absolutePath,
            "--ip", "127.0.0.1",
            "--port", ep.port.toString(),
            "--path", dir.absolutePath,
            "--httpauth",
        )
        pb.directory(dir)
        pb.environment()["HOME"] = dir.absolutePath
        pb.environment()["TMPDIR"] = ctx.cacheDir.absolutePath
        pb.redirectErrorStream(true)
        pb.redirectOutput(ProcessBuilder.Redirect.to(File("/dev/null")))
        val p = pb.start()
        process = p
        pidOf(p)?.let { pidFile.writeText(it.toString()) }
        Thread({ watch(p, ep) }, "torrserver-watch").apply { isDaemon = true }.start()
    }

    /** Relance le processus s'il meurt sans qu'on l'ait demandé (5 fois par minute au plus). */
    private fun watch(p: Process, ep: Endpoint) {
        try {
            p.waitFor()
        } catch (e: InterruptedException) {
            return
        }
        synchronized(lock) {
            if (!wanted || process !== p) return
            val now = System.currentTimeMillis()
            while (restarts.isNotEmpty() && now - restarts.first() > 60_000) restarts.removeFirst()
            if (restarts.size >= 5) {
                Log.w(tag, "trop de redémarrages, abandon")
                wanted = false
                process = null
                return
            }
            restarts.addLast(now)
            Log.w(tag, "processus arrêté (code ${p.exitValue()}), relance")
            try {
                spawn(ep) // même port et même mot de passe : les URL restent valables
            } catch (e: Exception) {
                Log.w(tag, "relance impossible : ${e.javaClass.simpleName}")
                wanted = false
                process = null
            }
        }
    }

    /** Tue un TorrServer resté d'une session précédente (application tuée sans arrêt propre). */
    private fun killOrphan() {
        try {
            val pid = pidFile.takeIf { it.exists() }?.readText()?.trim()?.toIntOrNull() ?: return
            val cmd = File("/proc/$pid/cmdline").takeIf { it.exists() }?.readText() ?: ""
            if (cmd.contains("libtorrserver")) {
                android.os.Process.killProcess(pid)
                Log.i(tag, "ancien processus arrêté")
            }
        } catch (e: Exception) {
            Log.w(tag, "nettoyage de l'ancien processus impossible : ${e.javaClass.simpleName}")
        } finally {
            pidFile.delete()
        }
    }

    private fun pidOf(p: Process): Int? = try {
        val f = p.javaClass.getDeclaredField("pid")
        f.isAccessible = true
        f.getInt(p)
    } catch (e: Exception) {
        null
    }

    private fun freePort(): Int =
        ServerSocket(0, 0, InetAddress.getByName("127.0.0.1")).use { it.localPort }

    private fun randomSecret(): String {
        val b = ByteArray(32)
        SecureRandom().nextBytes(b)
        return b.joinToString("") { "%02x".format(it) }
    }
}

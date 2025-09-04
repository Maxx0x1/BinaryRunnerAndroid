package com.example.binaryrunner

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.io.InterruptedIOException
import java.io.IOException

class MainActivity : FlutterActivity() {
	private val channelNames = listOf(
		"com.example.binaryrunner/runner"
	)
	@Volatile private var currentProcess: Process? = null
	private val processLock = Any()

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		channelNames.forEach { name ->
			MethodChannel(flutterEngine.dartExecutor.binaryMessenger, name)
				.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
					when (call.method) {
						"runBinary" -> {
							val path = call.argument<String>("path")
							val binaryName = call.argument<String>("binaryName")
							val args = call.argument<List<String>>("args") ?: emptyList()
							val useSu = call.argument<Boolean>("useSu") ?: false
							if (binaryName.isNullOrBlank()) {
								result.error("ARG_ERROR", "binaryName is required", null)
								return@setMethodCallHandler
							}
							runBinaryAsync(path, binaryName, args, useSu, result)
						}
						"stopBinary" -> stopBinary(result)
						else -> result.notImplemented()
					}
				}
		}
	}

	private fun runBinaryAsync(path: String?, binaryName: String, args: List<String>, useSu: Boolean, result: MethodChannel.Result) {
		Thread {
			val res = runCatching {
				val usePath = path?.trim().orEmpty()
				val resolvedExec = resolveExecutable(usePath, binaryName)

				if (resolvedExec.startsWith("/")) {
					try { File(resolvedExec).setExecutable(true) } catch (_: Throwable) {}
				}

				val command = if (useSu) {
					val cmdString = buildString {
						append(escapeArg(resolvedExec))
						args.forEach { append(' ').append(escapeArg(it)) }
					}
					mutableListOf("su", "-c", cmdString)
				} else {
					mutableListOf(resolvedExec).apply { addAll(args) }
				}

				// Build a human-friendly display command without per-token quotes,
				// e.g. /system/bin/ls --color=always
				val displayCommand = buildString {
					append(resolvedExec)
					args.forEach { append(' ').append(it) }
				}

				val builder = ProcessBuilder(command).redirectErrorStream(false)
				if (usePath.isNotBlank()) builder.directory(File(usePath))

				val process = builder.start()
				synchronized(processLock) { currentProcess = process }

				val stdout = StringBuilder()
				val stderr = StringBuilder()

				val outThread = Thread {
					try {
						BufferedReader(InputStreamReader(process.inputStream)).use { br ->
							var line: String?
							while (true) {
								line = br.readLine() ?: break
								stdout.append(line).append('\n')
							}
						}
					} catch (_: InterruptedIOException) {
						// Stream was interrupted (likely due to stop); ignore.
					} catch (_: IOException) {
						// Stream closed; ignore.
					} catch (_: Throwable) {
						// Defensive: never crash the app from a gobbler thread.
					}
				}
				val errThread = Thread {
					try {
						BufferedReader(InputStreamReader(process.errorStream)).use { br ->
							var line: String?
							while (true) {
								line = br.readLine() ?: break
								stderr.append(line).append('\n')
							}
						}
					} catch (_: InterruptedIOException) {
						// Interrupted; ignore.
					} catch (_: IOException) {
						// Closed; ignore.
					} catch (_: Throwable) {
						// Defensive.
					}
				}
				outThread.start()
				errThread.start()

				val exitCode = process.waitFor()
				outThread.join()
				errThread.join()

				synchronized(processLock) { currentProcess = null }

				mapOf(
					"stdout" to stdout.toString(),
					"stderr" to stderr.toString(),
					"exitCode" to exitCode,
					"command" to displayCommand
				)
			}

			Handler(Looper.getMainLooper()).post {
				res.onSuccess { map -> result.success(map) }
					.onFailure { e -> result.error("EXEC_ERROR", e.message, null) }
			}
		}.start()
	}

	private fun stopBinary(result: MethodChannel.Result) {
		Thread {
			val stopped = runCatching {
				val p: Process? = synchronized(processLock) { currentProcess }
				if (p == null) {
					false
				} else {
					try {
						p.destroy()
						var waited = 0
						while (isAlive(p) && waited < 800) {
							Thread.sleep(50)
							waited += 50
						}
						if (isAlive(p)) p.destroyForcibly()
						true
					} finally {
						synchronized(processLock) { if (!isAlive(p)) currentProcess = null }
					}
				}
			}.getOrDefault(false)

			Handler(Looper.getMainLooper()).post {
				result.success(mapOf("stopped" to stopped))
			}
		}.start()
	}

	private fun resolveExecutable(path: String, binaryName: String): String {
		if (path.isBlank()) {
			val candidates = listOf(
				"/system/bin",
				"/system/xbin",
				"/product/bin",
				"/vendor/bin",
				"/apex/com.android.runtime/bin",
				"/apex/com.android.art/bin"
			)
			for (dir in candidates) {
				val f = File(dir, binaryName)
				if (f.exists() && f.canExecute()) return f.absolutePath
			}
			return binaryName
		}
		return File(path, binaryName).absolutePath
	}

	private fun isAlive(p: Process?): Boolean {
		if (p == null) return false
		return try {
			p.exitValue()
			false
		} catch (_: IllegalThreadStateException) {
			true
		}
	}

	private fun escapeArg(arg: String): String {
		val escaped = arg.replace("'", "'\\''")
		return "'$escaped'"
	}
}


package com.example.profilertestapp

import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
	private val channelName = "com.example.profilertestapp/runner"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
				when (call.method) {
					"runBinary" -> {
						val path = call.argument<String>("path")
						val binaryName = call.argument<String>("binaryName")
						val args = call.argument<List<String>>("args") ?: emptyList()
						val useSu = call.argument<Boolean>("useSu") ?: false
						if (path.isNullOrBlank() || binaryName.isNullOrBlank()) {
							result.error("ARG_ERROR", "path and binaryName are required", null)
							return@setMethodCallHandler
						}
						runBinaryAsync(path, binaryName, args, useSu, result)
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun runBinaryAsync(path: String, binaryName: String, args: List<String>, useSu: Boolean, result: MethodChannel.Result) {
		Thread {
			val res = runCatching {
				val fullPath = File(path, binaryName).absolutePath
				// Ensure executable bit if possible (requires root or correct perms)
				try { File(fullPath).setExecutable(true) } catch (_: Throwable) {}

				val command = if (useSu) {
					// su -c "<fullPath> arg1 arg2 ..."
					val cmdString = buildString {
						append(escapeArg(fullPath))
						args.forEach { append(' ').append(escapeArg(it)) }
					}
					mutableListOf("su", "-c", cmdString)
				} else {
					mutableListOf(fullPath).apply { addAll(args) }
				}

				val process = ProcessBuilder(command)
					.redirectErrorStream(false)
					.directory(File(path))
					.start()

				val stdout = StringBuilder()
				val stderr = StringBuilder()

				val outThread = Thread {
					BufferedReader(InputStreamReader(process.inputStream)).use { br ->
						var line: String?
						while (br.readLine().also { line = it } != null) {
							stdout.append(line).append('\n')
						}
					}
				}
				val errThread = Thread {
					BufferedReader(InputStreamReader(process.errorStream)).use { br ->
						var line: String?
						while (br.readLine().also { line = it } != null) {
							stderr.append(line).append('\n')
						}
					}
				}
				outThread.start()
				errThread.start()

				val exitCode = process.waitFor()
				outThread.join()
				errThread.join()

				mapOf(
					"stdout" to stdout.toString(),
					"stderr" to stderr.toString(),
					"exitCode" to exitCode
				)
			}

			val ui = Handler(Looper.getMainLooper())
			ui.post {
				res.onSuccess { map -> result.success(map) }
					.onFailure { e -> result.error("EXEC_ERROR", e.message, null) }
			}
		}.start()
	}

	private fun escapeArg(arg: String): String {
		// Minimal escaping for shell when using su -c
		// Wrap in single quotes and escape existing single quotes.
		val escaped = arg.replace("'", "'\\''")
		return "'$escaped'"
	}
}

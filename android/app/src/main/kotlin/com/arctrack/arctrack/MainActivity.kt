package com.arctrack.arctrack

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.SystemClock
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val navigationChannel = "com.arctrack.arctrack/navigation"
    private val backupChannel = "com.arctrack.arctrack/backup"
    private val backupRequestCode = 4701
    private val existingBackupRequestCode = 4702
    private val backupPreferences = "arctrack_backup"
    private val backupUriKey = "destination_uri"
    private val backupExecutor = Executors.newSingleThreadExecutor()
    private var fallbackBackPressedAt = 0L
    private var pendingBackupResult: MethodChannel.Result? = null
    private var pendingBackupJson: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(savedBackupUri() != null)
                    "chooseDestination" -> {
                        if (pendingBackupResult != null) {
                            result.error("busy", "A backup destination is already being selected.", null)
                        } else {
                            pendingBackupResult = result
                            pendingBackupJson = call.argument<String>("json") ?: ""
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/json"
                                addFlags(
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                                )
                                putExtra(Intent.EXTRA_TITLE, "ArcTrack_backup.json")
                            }
                            startActivityForResult(intent, backupRequestCode)
                        }
                    }
                    "useExistingDestination" -> {
                        if (pendingBackupResult != null) {
                            result.error("busy", "A backup destination is already being selected.", null)
                        } else {
                            pendingBackupResult = result
                            pendingBackupJson = call.argument<String>("json") ?: ""
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/json"
                                addFlags(
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                                )
                            }
                            startActivityForResult(intent, existingBackupRequestCode)
                        }
                    }
                    "write" -> {
                        val uri = savedBackupUri()
                        if (uri == null) {
                            result.success(false)
                        } else {
                            writeBackup(uri, call.argument<String>("json") ?: "", result)
                        }
                    }
                    "disable" -> {
                        val uri = savedBackupUri()
                        if (uri != null) {
                            try {
                                contentResolver.releasePersistableUriPermission(
                                    uri,
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                                )
                            } catch (_: Exception) {
                            }
                        }
                        getSharedPreferences(backupPreferences, MODE_PRIVATE)
                            .edit().remove(backupUriKey).apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != backupRequestCode &&
            requestCode != existingBackupRequestCode) return
        val result = pendingBackupResult
        val json = pendingBackupJson.orEmpty()
        pendingBackupResult = null
        pendingBackupJson = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result?.success(false)
            return
        }
        try {
            val grantedFlags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(uri, grantedFlags)
            getSharedPreferences(backupPreferences, MODE_PRIVATE)
                .edit().putString(backupUriKey, uri.toString()).apply()
            if (result != null) writeBackup(uri, json, result)
        } catch (error: Exception) {
            result?.error("backup_destination", error.message, null)
        }
    }

    private fun savedBackupUri(): Uri? =
        getSharedPreferences(backupPreferences, MODE_PRIVATE)
            .getString(backupUriKey, null)?.let(Uri::parse)

    private fun writeBackup(uri: Uri, json: String, result: MethodChannel.Result) {
        backupExecutor.execute {
            try {
                contentResolver.openOutputStream(uri, "wt").use { stream ->
                    requireNotNull(stream) { "The selected backup file is unavailable." }
                    stream.write(json.toByteArray(Charsets.UTF_8))
                    stream.flush()
                }
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread { result.error("backup_write", error.message, null) }
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        val engine = flutterEngine
        if (engine == null) {
            handleFallbackBack()
            return
        }

        MethodChannel(engine.dartExecutor.binaryMessenger, navigationChannel)
            .invokeMethod("systemBack", null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (result == true) finishAndRemoveTask()
                }

                override fun error(code: String, message: String?, details: Any?) {
                    handleFallbackBack()
                }

                override fun notImplemented() {
                    handleFallbackBack()
                }
            })
    }

    private fun handleFallbackBack() {
        val now = SystemClock.elapsedRealtime()
        if (now - fallbackBackPressedAt <= 2000L) {
            finishAndRemoveTask()
            return
        }
        fallbackBackPressedAt = now
        Toast.makeText(this, "Press back again to exit", Toast.LENGTH_SHORT).show()
    }
}

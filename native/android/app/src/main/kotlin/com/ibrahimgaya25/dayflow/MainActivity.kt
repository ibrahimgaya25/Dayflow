package com.ibrahimgaya25.dayflow

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val PICK_JSON_REQUEST = 9042
    }

    private var pendingPickerResult: MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_JSON_REQUEST) return
        val result = pendingPickerResult
        pendingPickerResult = null
        if (result == null) return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val text = contentResolver.openInputStream(uri)
                ?.bufferedReader(Charsets.UTF_8)
                ?.use { it.readText() }
            result.success(text)
        } catch (error: Exception) {
            result.error("read_failed", "The selected backup could not be read.", error.message)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ibrahimgaya25.dayflow/files"
        ).setMethodCallHandler { call, result ->
            if (call.method != "pickJson") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingPickerResult != null) {
                result.error("picker_busy", "A file picker is already open.", null)
                return@setMethodCallHandler
            }
            pendingPickerResult = result
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/json"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain"))
            }
            startActivityForResult(intent, PICK_JSON_REQUEST)
        }
    }
}

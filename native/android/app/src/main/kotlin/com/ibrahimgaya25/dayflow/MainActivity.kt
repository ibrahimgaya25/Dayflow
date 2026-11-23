package com.ibrahimgaya25.dayflow

import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPickerResult: MethodChannel.Result? = null

    private val jsonPicker = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        val result = pendingPickerResult
        pendingPickerResult = null
        if (result == null) return@registerForActivityResult
        if (uri == null) {
            result.success(null)
            return@registerForActivityResult
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
            jsonPicker.launch(arrayOf("application/json", "text/plain"))
        }
    }
}

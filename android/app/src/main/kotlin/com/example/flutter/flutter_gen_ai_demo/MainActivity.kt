package com.example.flutter.flutter_gen_ai_demo

import ai.onnxruntime.genai.GenAIException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.io.FileOutputStream
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private var eventSink: EventChannel.EventSink? = null
    private val genAIWrapper = GenAIWrapper()

    companion object {
        private const val METHOD_CHANNEL = "com.example.flutter.flutter_gen_ai_demo/channel/method"
        private const val EVENT_CHANNEL = "com.example.flutter.flutter_gen_ai_demo/channel/event"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "load" -> handleLoadModel(call.arguments as String, result)
                "inference" -> handleInference(call, result)
                "unload" -> handleUnloadModel(result)
                "copyModelFromUri" -> handleCopyModelFromUri(call, result)
                else -> result.error("UNAVAILABLE", "No such method", null)
            }
        }

        EventChannel(flutterEngine.dartExecutor, EVENT_CHANNEL).setStreamHandler(object :
            EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun handleLoadModel(path: String, result: MethodChannel.Result) {
        val isLoaded = genAIWrapper.load(path)
        if (isLoaded) {
            result.success("LOADED")
        } else {
            result.error("LOAD_FAILED", "Failed to load model", null)
        }
    }

    private fun handleInference(
        call: MethodCall, result: MethodChannel.Result
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val prompt = call.argument<String>("prompt") ?: ""
                val params = call.argument<Map<String, Double>>("params") ?: mapOf()

                val success = genAIWrapper.inference(prompt, params) { token ->
                    eventSink?.success(token)
                }
                withContext(Dispatchers.Main) {
                    if (success) {
                        result.success("DONE")
                    } else {
                        result.error("INFERENCE_FAILED", "Inference failed", null)
                    }
                }
            } catch (e: GenAIException) {
                withContext(Dispatchers.Main) {
                    result.error("INFERENCE_FAILED", e.message, null)
                }
            }
        }
    }

    private fun handleUnloadModel(result: MethodChannel.Result) {
        genAIWrapper.unload()
        result.success("UNLOADED")
    }

    private fun handleCopyModelFromUri(call: MethodCall, result: MethodChannel.Result) {
        val folderUri = call.argument<String>("folderUri")
        val targetDir = call.argument<String>("targetDir")
        val files = call.argument<List<String>>("files")
        if (folderUri == null || targetDir == null || files == null) {
            result.error("INVALID_ARGS", "Missing folderUri, targetDir, or files", null)
            return
        }
        try {
            val uri = Uri.parse(folderUri)
            val tree = DocumentFile.fromTreeUri(this, uri)
            if (tree == null) {
                result.error("COPY_FAILED", "Unable to access folder", null)
                return
            }
            val target = File(targetDir)
            if (!target.exists()) {
                target.mkdirs()
            }
            val missing = mutableListOf<String>()
            for (fileName in files) {
                val source = tree.findFile(fileName)
                if (source == null) {
                    missing.add(fileName)
                    continue
                }
                val outFile = File(target, fileName)
                if (outFile.exists() && outFile.length() > 0) {
                    continue
                }
                contentResolver.openInputStream(source.uri)?.use { input ->
                    FileOutputStream(outFile).use { output ->
                        input.copyTo(output)
                    }
                }
            }
            if (missing.isNotEmpty()) {
                result.error("COPY_FAILED", "Missing files: ${missing.joinToString(", ")}", null)
                return
            }
            result.success("COPIED")
        } catch (e: Exception) {
            result.error("COPY_FAILED", e.message, null)
        }
    }
}

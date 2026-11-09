package cn.wcg.photoid

import android.graphics.BitmapFactory
import android.content.Intent
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var photoFinder: PhotoFinderBridge? = null
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (photoFinder?.onActivityResult(requestCode,resultCode,data)==true) return
        super.onActivityResult(requestCode,resultCode,data)
    }
    private val recognitionExecutor = Executors.newSingleThreadExecutor()

    override fun onDestroy() {
        photoFinder?.dispose()
        recognitionExecutor.shutdown()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        photoFinder = PhotoFinderBridge(this,flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "photoid/requirements_ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("invalid_image", "Missing image", null)
                    return@setMethodCallHandler
                }
                recognitionExecutor.execute { recognizeImage(path, result) }
            }
    }

    // File decoding can be expensive; never perform it on the UI thread.
    private fun recognizeImage(path: String, result: MethodChannel.Result) {
        try {
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, options)
            if (File(path).length() > 30L * 1024 * 1024 ||
                options.outWidth <= 0 || options.outHeight <= 0 ||
                options.outWidth.toLong() * options.outHeight > 24_000_000L
            ) {
                runOnUiThread { result.error("invalid_image", "Unreadable or oversized image", null) }
                return
            }
            val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
            val chinese = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
            val latin = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            val close = { chinese.close(); latin.close() }
            chinese.process(image).addOnSuccessListener { first ->
                latin.process(image).addOnSuccessListener { second ->
                    try {
                        result.success((first.text.split("\n") + second.text.split("\n"))
                            .distinct().joinToString("\n"))
                    } finally { close() }
                }.addOnFailureListener {
                    close()
                    result.error("recognition_failed", "Text recognition failed", null)
                }
            }.addOnFailureListener {
                close()
                result.error("recognition_failed", "Text recognition failed", null)
            }
        } catch (_: Exception) {
            runOnUiThread {
                result.error("recognition_failed", "Text recognition unavailable or failed", null)
            }
        }
    }
}

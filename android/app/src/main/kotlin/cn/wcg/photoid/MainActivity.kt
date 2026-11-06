package cn.wcg.photoid

import android.graphics.BitmapFactory
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "photoid/requirements_ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") { result.notImplemented(); return@setMethodCallHandler }
                val path = call.argument<String>("path")
                if (path == null) { result.error("invalid_image", "Missing image", null); return@setMethodCallHandler }
                try {
                    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeFile(path, options)
                    if (File(path).length() > 30L * 1024 * 1024 || options.outWidth <= 0 || options.outHeight <= 0 || options.outWidth.toLong() * options.outHeight > 24_000_000L) {
                        result.error("invalid_image", "Unreadable or oversized image", null); return@setMethodCallHandler
                    }
                    val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                    val chinese = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
                    val latin = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                    chinese.process(image).addOnSuccessListener { first ->
                        latin.process(image).addOnSuccessListener { second ->
                            result.success((first.text.split("\n") + second.text.split("\n")).distinct().joinToString("\n"))
                            chinese.close(); latin.close()
                        }.addOnFailureListener {
                            chinese.close(); latin.close(); result.error("recognition_failed", "Text recognition failed", null)
                        }
                    }.addOnFailureListener {
                        chinese.close(); latin.close(); result.error("recognition_failed", "Text recognition failed", null)
                    }
                } catch (_: Exception) { result.error("recognition_failed", "Text recognition unavailable or failed", null) }
            }
    }
}

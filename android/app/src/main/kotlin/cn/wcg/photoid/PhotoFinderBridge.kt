package cn.wcg.photoid

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.math.max

/** Never converts content URIs to guessed filesystem paths or persists SAF grants. */
class PhotoFinderBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private data class Entry(val uri: Uri, val name: String, val relative: String)
    private class Session(val dir: File) {
        val id = dir.name
        val entries = linkedMapOf<String, Entry>()
        @Volatile var active = true
        var cacheBytes = 0L
    }
    private val executor = Executors.newSingleThreadExecutor()
    private val sessions = mutableMapOf<String, Session>()
    private val root = File(activity.cacheDir, "photoid_finder")
    private var pending: MethodChannel.Result? = null
    private var recursive = false
    private var directory = false
    private val pickerRequest = 19091
    init {
        root.mkdirs()
        root.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 86_400_000L }?.forEach { it.deleteRecursively() }
        MethodChannel(messenger, "photoid/photo_finder").setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            when (call.method) {
                "chooseDirectory", "chooseFiles" -> {
                    if (pending != null) { result.error("busy", "Picker busy", null); return@setMethodCallHandler }
                    pending = result
                    recursive = args["recursive"] == true
                    directory = call.method == "chooseDirectory"
                    val intent = if (directory) Intent(Intent.ACTION_OPEN_DOCUMENT_TREE) else
                        Intent(Intent.ACTION_OPEN_DOCUMENT).apply { type = "image/*"; addCategory(Intent.CATEGORY_OPENABLE); putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true) }
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    try { activity.startActivityForResult(intent, pickerRequest) }
                    catch (_: Exception) { pending = null; result.error("access", "Picker unavailable", null) }
                }
                "openDemo" -> executor.execute {
                    try {
                        val paths = args["paths"] as? List<*> ?: throw FinderFailure("access")
                        if (paths.isEmpty() || paths.size > 500) throw FinderFailure("access")
                        val files = paths.map { File(it as String).canonicalFile }
                        val roots = listOf(activity.filesDir.parentFile!!.canonicalPath + "/")
                        if (files.any { file -> roots.none { file.path.startsWith(it) } }) throw FinderFailure("access")
                        create(files.map { Entry(Uri.fromFile(it), it.name, it.name) }, false, false, result)
                    } catch (e: Exception) { fail(e, result) }
                }
                "analyze", "materialize", "close", "interrupt" -> executor.execute {
                    try {
                        val id = args["session"] as? String
                        val s = sessions[id]
                        if (call.method == "close") {
                            if (s != null) { s.active = false; sessions.remove(id); s.dir.deleteRecursively() }
                            reply(null, result); return@execute
                        }
                        if (call.method == "interrupt") { reply(null, result); return@execute }
                        if (s == null || !s.active) throw FinderFailure("closed")
                        val key = args["id"] as? String ?: throw FinderFailure("access")
                        val entry = s.entries[key] ?: throw FinderFailure("access")
                        if (call.method == "analyze") analyze(s, key, entry, result)
                        else materialize(s, key, entry, args["fingerprint"] as? String, result)
                    } catch (e: Exception) { fail(e, result) }
                }
                else -> result.notImplemented()
            }
        }
    }
    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != pickerRequest) return false
        val result = pending ?: return true
        pending = null
        if (code != Activity.RESULT_OK || data == null) { result.success(null); return true }
        val folder = directory; val descend = recursive
        executor.execute {
            try {
                val uris = mutableListOf<Uri>()
                data.clipData?.let { clip -> for (i in 0 until minOf(clip.itemCount, 501)) uris.add(clip.getItemAt(i).uri) }
                if (uris.isEmpty()) data.data?.let { uris.add(it) }
                if (uris.isEmpty()) throw FinderFailure("access")
                if (folder && uris.first().authority !in setOf("com.android.externalstorage.documents", "com.android.providers.downloads.documents")) throw FinderFailure("provider")
                create(uris.map { Entry(it, nameOf(it), nameOf(it)) }, folder, descend, result)
            } catch (e: Exception) { fail(e, result) }
        }
        return true
    }
    private fun nameOf(uri: Uri): String {
        if (uri.scheme == "file") return File(uri.path!!).name
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { if (it.moveToFirst()) return it.getString(0) ?: "photo" }
        return "photo"
    }
    private fun create(seeds: List<Entry>, folder: Boolean, descend: Boolean, result: MethodChannel.Result) {
        val s = Session(File(root, UUID.randomUUID().toString()))
        s.dir.mkdirs()
        try {
            var visited = 0; var limited = false
            fun add(entry: Entry) {
                if (entry.name.substringAfterLast('.', "").lowercase() in setOf("jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "webp", "tiff")) s.entries[UUID.randomUUID().toString()] = entry
            }
            if (folder) {
                val tree = seeds.first().uri
                val queue = java.util.ArrayDeque<Pair<String, Pair<String, Int>>>()
                queue.add(DocumentsContract.getTreeDocumentId(tree) to ("" to 0))
                val seen = mutableSetOf<String>()
                while (queue.isNotEmpty() && visited < 2000 && s.entries.size < 500) {
                    val (id, location) = queue.removeFirst(); val (prefix, depth) = location
                    if (!seen.add(id)) continue
                    val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, id)
                    activity.contentResolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE), null, null, null)?.use { cursor ->
                        while (cursor.moveToNext()) {
                            if (visited >= 2000 || s.entries.size >= 500) { limited = true; break }
                            visited++
                            val child = cursor.getString(0); val name = cursor.getString(1) ?: "photo"
                            val relative = if (prefix.isEmpty()) name else "$prefix/$name"
                            if (cursor.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                                if (descend && depth < 4) queue.add(child to (relative to depth + 1))
                            } else add(Entry(DocumentsContract.buildDocumentUriUsingTree(tree, child), name, relative))
                        }
                    } ?: throw FinderFailure("access")
                }
                if (queue.isNotEmpty() || visited >= 2000 || s.entries.size >= 500) limited = true
            } else { seeds.take(500).forEach { visited++; add(it) }; limited = seeds.size > 500 }
            sessions[s.id] = s
            reply(mapOf("session" to s.id, "visited" to visited, "truncated" to limited,
                "entries" to s.entries.map { (id, e) -> mapOf("id" to id, "name" to e.name, "relativePath" to e.relative) }.sortedBy { it["relativePath"] }), result)
        } catch (e: Exception) { s.active = false; s.dir.deleteRecursively(); throw e }
    }
    private fun raw(s: Session, entry: Entry, suffix: String): File {
        if (entry.name.substringAfterLast('.', "").lowercase() !in setOf("jpg", "jpeg", "png", "heic", "heif")) throw FinderFailure("unsupported")
        val file = File(s.dir, "$suffix.input")
        try {
            val input = if (entry.uri.scheme == "file") File(entry.uri.path!!).inputStream() else activity.contentResolver.openInputStream(entry.uri)
            input?.use { source -> FileOutputStream(file).use { out ->
                val buffer = ByteArray(65536); var total = 0L
                while (true) { val n = source.read(buffer); if (n < 0) break; total += n; if (total > 30L * 1024 * 1024) throw FinderFailure("oversized"); out.write(buffer, 0, n) }
            } } ?: throw FinderFailure("access")
            info(file)
            return file
        } catch (e: Exception) { file.delete(); throw e }
    }
    private fun info(file: File): Pair<Int, Int> {
        val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, o)
        if (o.outWidth <= 0 || o.outHeight <= 0) throw FinderFailure("unreadable")
        if (o.outWidth.toLong() * o.outHeight > 24_000_000L) throw FinderFailure("oversized")
        return o.outWidth to o.outHeight
    }
    private fun orientation(file: File) = try { ExifInterface(file.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1) } catch (_: Exception) { 1 }
    private fun bitmap(file: File, maxDimension: Int): Bitmap {
        val (w, h) = info(file); var sample = 1
        while (max(w, h) / sample > maxDimension) sample *= 2
        val b = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample }) ?: throw FinderFailure("unreadable")
        val matrix = Matrix()
        when (orientation(file)) {
            2 -> matrix.postScale(-1f, 1f); 3 -> matrix.postRotate(180f); 4 -> matrix.postScale(1f, -1f)
            5 -> { matrix.postRotate(90f); matrix.postScale(-1f, 1f) }
            6 -> matrix.postRotate(90f); 7 -> { matrix.postRotate(270f); matrix.postScale(-1f, 1f) }; 8 -> matrix.postRotate(270f)
        }
        if (matrix.isIdentity) return b
        return Bitmap.createBitmap(b, 0, 0, b.width, b.height, matrix, true).also { if (it !== b) b.recycle() }
    }
    private fun hash(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { val b = ByteArray(65536); while (true) { val n = it.read(b); if (n < 0) break; digest.update(b, 0, n) } }
        return digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
    }
    private fun analyze(s: Session, id: String, e: Entry, result: MethodChannel.Result) {
        var input: File? = null
        try {
            input = raw(s, e, id)
            val rawFile = input; val (w, h) = info(rawFile); val rotate = orientation(rawFile) in 5..8
            val fingerprint = hash(rawFile)
            val image = bitmap(rawFile, 1280); rawFile.delete(); input = null
            val detector = FaceDetection.getClient(FaceDetectorOptions.Builder().setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE).build())
            detector.process(InputImage.fromBitmap(image, 0)).addOnCompleteListener { task ->
                try {
                    if (!s.active) throw FinderFailure("closed")
                    if (!task.isSuccessful) throw FinderFailure("unreadable")
                    val thumb = File(s.dir, "$id.jpg")
                    FileOutputStream(thumb).use { image.compress(Bitmap.CompressFormat.JPEG, 90, it) }
                    s.cacheBytes += thumb.length()
                    if (s.cacheBytes > 100L*1024*1024) { thumb.delete(); throw FinderFailure("cacheLimit") }
                    val faces = task.result.map { f -> val b = f.boundingBox; mapOf("x" to b.left.toDouble()/image.width, "y" to b.top.toDouble()/image.height, "w" to b.width().toDouble()/image.width, "h" to b.height().toDouble()/image.height, "yaw" to f.headEulerAngleY.toDouble(), "roll" to f.headEulerAngleZ.toDouble()) }
                    reply(mapOf("width" to if(rotate)h else w,"height" to if(rotate)w else h,"faces" to faces,"thumbnailPath" to thumb.path,"fingerprint" to fingerprint),result)
                } catch (error: Exception) { reply(mapOf("skip" to (if(error is FinderFailure)error.message else "unreadable")),result) }
                finally { detector.close(); image.recycle() }
            }
        } catch (error: Exception) { input?.delete(); reply(mapOf("skip" to (if(error is FinderFailure)error.message else "unreadable")),result) }
    }
    private fun materialize(s: Session, id: String, e: Entry, expected: String?, result: MethodChannel.Result) {
        val input = raw(s, e, "verify_$id")
        try {
            if (hash(input) != expected) throw FinderFailure("changed")
            val ext = e.name.substringAfterLast('.', "").lowercase()
            val output = File(s.dir, "selected_$id.${if(ext in setOf("heic","heif"))"jpg" else ext}")
            if (ext in setOf("heic", "heif")) {
                val (width, height) = info(input)
                val image = bitmap(input, max(width, height))
                try { FileOutputStream(output).use { image.compress(Bitmap.CompressFormat.JPEG, 94, it) } } finally { image.recycle() }
            } else input.copyTo(output, overwrite=true)
            reply(mapOf("path" to output.path),result)
        } finally { input.delete() }
    }
    fun dispose() { executor.execute { sessions.values.forEach { it.active=false; it.dir.deleteRecursively() }; sessions.clear() }; executor.shutdown() }
    private fun reply(value: Any?, result: MethodChannel.Result) { activity.runOnUiThread { result.success(value) } }
    private fun fail(error: Exception, result: MethodChannel.Result) { activity.runOnUiThread { val code = if(error is FinderFailure)error.message else "access"; result.error(code ?: "access",code,null) } }
    private class FinderFailure(code: String): Exception(code)
}

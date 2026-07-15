package com.example.precarium

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import okhttp3.OkHttpClient
import okhttp3.Request
import org.schabi.newpipe.extractor.NewPipe
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class NativeExecutor(private val context: Context) {

    private val okHttp = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .followRedirects(true)
        .build()

    private val background = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var progressSink: EventChannel.EventSink? = null

    fun setProgressSink(sink: EventChannel.EventSink?) {
        progressSink = sink
    }

    companion object {
        private var initialized = false

        @Synchronized
        fun ensureInit() {
            if (!initialized) {
                NewPipe.init(NewPipeDownloader())
                initialized = true
            }
        }

        const val CHANNEL = "com.example.precarium/downloader"
        const val PROGRESS_CHANNEL = "com.example.precarium/download_progress"

        fun registerWith(engine: io.flutter.embedding.engine.FlutterEngine, context: Context) {
            ensureInit()
            val executor = NativeExecutor(context)

            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "extractAudio" -> {
                        val videoId = call.argument<String>("videoId")!!
                        executor.background.submit {
                            try {
                                val json = executor.extractAudio(videoId)
                                executor.mainHandler.post { result.success(json) }
                            } catch (e: Exception) {
                                executor.mainHandler.post { result.error("EXEC_ERROR", "${e.javaClass.simpleName}: ${e.message}", null) }
                            }
                        }
                    }
                    "download" -> {
                        val url = call.argument<String>("url")!!
                        val filePath = call.argument<String>("filePath")!!
                        executor.background.submit {
                            try {
                                executor.downloadAudio(url, filePath)
                                executor.mainHandler.post { result.success(filePath) }
                            } catch (e: Exception) {
                                executor.mainHandler.post { result.error("EXEC_ERROR", "${e.javaClass.simpleName}: ${e.message}", null) }
                            }
                        }
                    }
                    "getDuration" -> {
                        val filePath = call.argument<String>("filePath")!!
                        executor.background.submit {
                            try {
                                val ms = executor.getAudioDuration(filePath)
                                executor.mainHandler.post { result.success(ms) }
                            } catch (e: Exception) {
                                executor.mainHandler.post { result.error("EXEC_ERROR", "${e.javaClass.simpleName}: ${e.message}", null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

            val progressChannel = EventChannel(engine.dartExecutor.binaryMessenger, PROGRESS_CHANNEL)
            progressChannel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    executor.setProgressSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    executor.setProgressSink(null)
                }
            })
        }
    }

    fun extractAudio(videoId: String): String {
        val videoUrl = "https://youtube.com/watch?v=$videoId"
        val service = NewPipe.getService(0)
        val extractor = service.getStreamExtractor(videoUrl)
        extractor.fetchPage()

        val title = extractor.name ?: "Unknown"
        val audioStreams = extractor.audioStreams ?: emptyList()
        if (audioStreams.isEmpty()) throw Exception("No audio streams available")

        val opusStreams = audioStreams.filter { it.format?.suffix == ".webm" }
        val best = if (opusStreams.isNotEmpty()) {
            opusStreams.maxByOrNull { it.averageBitrate ?: 0 } ?: opusStreams[0]
        } else {
            audioStreams.maxByOrNull { it.averageBitrate ?: 0 } ?: audioStreams[0]
        }

        val audioUrl = best.url ?: throw Exception("Audio stream has no URL")
        val audioFormat = best.format
        val rawSuffix = audioFormat?.suffix?.removePrefix(".") ?: "m4a"
        val formatSuffix = if (rawSuffix == "webm") "opus" else rawSuffix
        val bitrate = best.averageBitrate ?: 0

        return """{"url":"${escapeJson(audioUrl)}","format":"$formatSuffix","bitrate":$bitrate,"title":"${escapeJson(title)}"}"""
    }

    fun downloadAudio(url: String, filePath: String) {
        val request = Request.Builder().url(url)
            .header("User-Agent", "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36")
            .header("Accept", "*/*")
            .header("Accept-Encoding", "identity")
            .build()
        val response = okHttp.newCall(request).execute()
        if (!response.isSuccessful) throw Exception("HTTP ${response.code}")
        val body = response.body ?: throw Exception("No response body")
        val contentLength = body.contentLength()
        val output = FileOutputStream(File(filePath))
        try {
            val input = body.byteStream()
            val buffer = ByteArray(8192)
            var totalRead = 0L
            var bytesRead: Int
            while (input.read(buffer).also { bytesRead = it } != -1) {
                output.write(buffer, 0, bytesRead)
                totalRead += bytesRead
                if (contentLength > 0) {
                    val pct = ((totalRead.toDouble() / contentLength.toDouble()) * 100).toInt()
                    mainHandler.post { progressSink?.success(pct) }
                }
            }
            mainHandler.post { progressSink?.success(100) }
        } finally {
            output.close()
        }
    }

    fun getAudioDuration(filePath: String): Long {
        val retriever = android.media.MediaMetadataRetriever()
        try {
            retriever.setDataSource(filePath)
            val durationStr = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)
            return durationStr?.toLongOrNull() ?: 0L
        } finally {
            retriever.release()
        }
    }

    private fun escapeJson(s: String): String {
        return s.replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
    }
}

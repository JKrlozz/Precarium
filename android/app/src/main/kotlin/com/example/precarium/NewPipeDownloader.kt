package com.example.precarium

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.RequestBody
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import java.util.concurrent.TimeUnit

class NewPipeDownloader : Downloader() {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(true)
        .build()

    override fun execute(request: Request): Response {
        val reqBuilder = okhttp3.Request.Builder().url(request.url())
        reqBuilder.header("User-Agent", "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36")

        for ((key, values) in request.headers()) {
            for (value in values) {
                reqBuilder.addHeader(key, value)
            }
        }

        val data = request.dataToSend()
        val body = if (data != null && data.isNotEmpty()) {
            val contentType = request.headers()["Content-Type"]?.firstOrNull()
            RequestBody.create(contentType?.toMediaType(), data)
        } else null

        val okRequest = reqBuilder.method(request.httpMethod(), body).build()
        val okResponse = client.newCall(okRequest).execute()
        val responseBody = okResponse.body?.string() ?: ""
        val latestUrl = okResponse.request.url.toString()

        return Response(
            okResponse.code,
            okResponse.message,
            okResponse.headers.toMultimap(),
            responseBody,
            latestUrl,
        )
    }
}

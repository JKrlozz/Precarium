package com.example.precarium

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MediaNotificationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private var channel: MethodChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var context: Context? = null
    private var notificationManager: NotificationManager? = null
    private var mediaSession: MediaSessionCompat? = null
    private var receiverRegistered = false
    private val actionReceiver = ActionReceiver()

    private var currentTitle = ""
    private var currentArtist = ""
    private var currentAlbumArtPath: String? = null
    private var isPlaying = false

    private var downloadCompletedCount = 0
    private var downloadTotalCount = 0
    private var downloadActive = false

    companion object {
        const val CHANNEL = "com.example.precarium/media_notification"
        const val EVENT_CHANNEL = "com.example.precarium/media_notification_events"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "precarium_media"

        const val DOWNLOAD_NOTIFICATION_ID = 1002
        const val DOWNLOAD_CHANNEL_ID = "precarium_download"
        const val DOWNLOAD_FOREGROUND_SERVICE_ID = 1003

        const val ACTION_PLAY = "com.example.precarium.PLAY"
        const val ACTION_PAUSE = "com.example.precarium.PAUSE"
        const val ACTION_NEXT = "com.example.precarium.NEXT"
        const val ACTION_PREVIOUS = "com.example.precarium.PREVIOUS"
        const val ACTION_STOP = "com.example.precarium.STOP"
    }

    class ActionReceiver : BroadcastReceiver() {
        var onAction: ((String) -> Unit)? = null

        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action ?: return
            onAction?.invoke(action)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
        setupEventChannel(binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        createNotificationChannel()
        setupMediaSession()
        registerReceiver()
    }

    override fun onDetachedFromActivity() {
        hideNotification()
        unregisterReceiver()
        mediaSession?.release()
        mediaSession = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    private fun setupEventChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                eventSink = events
                actionReceiver.onAction = { action ->
                    val event = when (action) {
                        ACTION_PLAY -> "play"
                        ACTION_PAUSE -> "pause"
                        ACTION_NEXT -> "next"
                        ACTION_PREVIOUS -> "previous"
                        ACTION_STOP -> "stop"
                        else -> null
                    }
                    if (event != null) events.success(event)
                }
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                actionReceiver.onAction = null
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "update" -> {
                currentTitle = call.argument<String>("title") ?: ""
                currentArtist = call.argument<String>("artist") ?: ""
                currentAlbumArtPath = call.argument<String>("albumArtPath")
                isPlaying = call.argument<Boolean>("isPlaying") ?: false
                showNotification()
                result.success(null)
            }
            "hide" -> {
                hideNotification()
                result.success(null)
            }
            "showDownload" -> {
                val total = call.argument<Number>("total")?.toInt() ?: 1
                val completed = call.argument<Number>("completed")?.toInt() ?: 0
                downloadTotalCount = total
                downloadCompletedCount = completed
                downloadActive = true
                showDownloadNotification()
                result.success(null)
            }
            "updateDownload" -> {
                val completed = call.argument<Number>("completed")?.toInt() ?: 0
                val total = call.argument<Number>("total")?.toInt() ?: 1
                downloadCompletedCount = completed
                downloadTotalCount = total
                updateDownloadNotification()
                result.success(null)
            }
            "hideDownload" -> {
                downloadActive = false
                hideDownloadNotification()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Reproducción de música",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Controla la reproducción de música"
                setShowBadge(false)
            }
            val downloadChannel = NotificationChannel(
                DOWNLOAD_CHANNEL_ID, "Descargas",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Progreso de descargas"
                setShowBadge(false)
            }
            notificationManager = context?.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager?.createNotificationChannel(channel)
            notificationManager?.createNotificationChannel(downloadChannel)
        }
    }

    private fun setupMediaSession() {
        val ctx = context ?: return
        val session = MediaSessionCompat(ctx, "PrecariumMediaSession")
        session.setFlags(
            MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
            MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
        )
        session.isActive = true
        session.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() { eventSink?.success("play") }
            override fun onPause() { eventSink?.success("pause") }
            override fun onSkipToNext() { eventSink?.success("next") }
            override fun onSkipToPrevious() { eventSink?.success("previous") }
            override fun onStop() { eventSink?.success("stop") }
        })
        mediaSession = session
    }

    private fun showNotification() {
        val ctx = context ?: return
        val session = mediaSession ?: return
        val notif = buildNotification(ctx, session)

        notificationManager?.notify(NOTIFICATION_ID, notif)

        val serviceIntent = Intent(ctx, MediaForegroundService::class.java).apply {
            putExtra("notification", notif)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.startForegroundService(serviceIntent)
        } else {
            ctx.startService(serviceIntent)
        }

        updateMediaSessionMetadata()
        updateMediaSessionPlaybackState()
    }

    private fun buildNotification(ctx: Context, session: MediaSessionCompat): Notification {
        val ppAction = if (isPlaying) {
            NotificationCompat.Action.Builder(
                android.R.drawable.ic_media_pause, "Pausar",
                makePendingIntent(ACTION_PAUSE)
            ).build()
        } else {
            NotificationCompat.Action.Builder(
                android.R.drawable.ic_media_play, "Reproducir",
                makePendingIntent(ACTION_PLAY)
            ).build()
        }

        return NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(currentTitle.ifEmpty { "Precarium" })
            .setContentText(currentArtist.ifEmpty { "Sin reproducir" })
            .setContentIntent(makeOpenAppIntent())
            .setDeleteIntent(makePendingIntent(ACTION_STOP))
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setStyle(
                MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
                    .setShowCancelButton(true)
                    .setCancelButtonIntent(makePendingIntent(ACTION_STOP))
            )
            .addAction(android.R.drawable.ic_media_previous, "Anterior", makePendingIntent(ACTION_PREVIOUS))
            .addAction(ppAction)
            .addAction(android.R.drawable.ic_media_next, "Siguiente", makePendingIntent(ACTION_NEXT))
            .setOngoing(isPlaying)
            .build()
    }

    private fun hideNotification() {
        notificationManager?.cancel(NOTIFICATION_ID)
        context?.stopService(Intent(context, MediaForegroundService::class.java))
    }

    private fun showDownloadNotification() {
        val ctx = context ?: return
        val notif = buildDownloadNotification(ctx)
        notificationManager?.notify(DOWNLOAD_NOTIFICATION_ID, notif)
        val serviceIntent = Intent(ctx, DownloadForegroundService::class.java).apply {
            putExtra("notification", notif)
            putExtra("notificationId", DOWNLOAD_NOTIFICATION_ID)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.startForegroundService(serviceIntent)
        } else {
            ctx.startService(serviceIntent)
        }
    }

    private fun updateDownloadNotification() {
        val ctx = context ?: return
        val notif = buildDownloadNotification(ctx)
        notificationManager?.notify(DOWNLOAD_NOTIFICATION_ID, notif)
    }

    private fun hideDownloadNotification() {
        notificationManager?.cancel(DOWNLOAD_NOTIFICATION_ID)
        context?.stopService(Intent(context, DownloadForegroundService::class.java))
    }

    private fun buildDownloadNotification(ctx: Context): Notification {
        val progressPercent = if (downloadTotalCount > 0) {
            ((downloadCompletedCount.toDouble() / downloadTotalCount) * 100).toInt()
        } else {
            0
        }
        val contentText = when {
            downloadTotalCount > 1 -> "$downloadCompletedCount de $downloadTotalCount canciones ($progressPercent%)"
            downloadCompletedCount > 0 -> "Canción $downloadCompletedCount de $downloadTotalCount ($progressPercent%)"
            else -> "Iniciando descarga..."
        }
        return NotificationCompat.Builder(ctx, DOWNLOAD_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_save)
            .setContentTitle("Descargando canciones")
            .setContentText(contentText)
            .setOngoing(true)
            .setProgress(downloadTotalCount, downloadCompletedCount, false)
            .setContentIntent(makeOpenAppIntent())
            .build()
    }

    private fun makePendingIntent(action: String): PendingIntent {
        val ctx = context ?: error("No context")
        val intent = Intent(action).setComponent(
            ComponentName(ctx, ActionReceiver::class.java)
        )
        return PendingIntent.getBroadcast(
            ctx, action.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun makeOpenAppIntent(): PendingIntent {
        val ctx = context ?: error("No context")
        val intent = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        return PendingIntent.getActivity(
            ctx, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun updateMediaSessionMetadata() {
        val session = mediaSession ?: return
        val art = loadAlbumArt()
        session.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist)
                .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, art)
                .build()
        )
    }

    private fun updateMediaSessionPlaybackState() {
        val session = mediaSession ?: return
        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setState(state, PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, 1f)
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackStateCompat.ACTION_STOP
                )
                .build()
        )
    }

    private fun loadAlbumArt(): android.graphics.Bitmap? {
        val path = currentAlbumArtPath ?: return null
        return try {
            val file = if (path.startsWith("content://")) {
                val uri = android.net.Uri.parse(path)
                val input = context?.contentResolver?.openInputStream(uri)
                input?.use { android.graphics.BitmapFactory.decodeStream(it) }
            } else {
                if (java.io.File(path).exists()) android.graphics.BitmapFactory.decodeFile(path) else null
            }
            file
        } catch (_: Exception) { null }
    }

    private fun registerReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(ACTION_PLAY); addAction(ACTION_PAUSE)
            addAction(ACTION_NEXT); addAction(ACTION_PREVIOUS)
            addAction(ACTION_STOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context?.registerReceiver(actionReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context?.registerReceiver(actionReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregisterReceiver() {
        if (!receiverRegistered) return
        try { context?.unregisterReceiver(actionReceiver) } catch (_: Exception) {}
        receiverRegistered = false
    }
}

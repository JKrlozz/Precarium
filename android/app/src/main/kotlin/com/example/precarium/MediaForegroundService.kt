package com.example.precarium

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.os.IBinder

class MediaForegroundService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = intent?.getParcelableExtra<Notification>("notification")
        if (notification != null) {
            startForeground(MediaNotificationPlugin.NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

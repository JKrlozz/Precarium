package com.example.precarium

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.os.IBinder

class DownloadForegroundService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = intent?.getParcelableExtra<Notification>("notification")
        val notificationId = intent?.getIntExtra("notificationId", MediaNotificationPlugin.DOWNLOAD_NOTIFICATION_ID)
        if (notification != null && notificationId != null) {
            startForeground(notificationId, notification)
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

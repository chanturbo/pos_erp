package com.dee_pos.poserp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder

class MasterHostService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        val deviceName = intent?.getStringExtra(EXTRA_DEVICE_NAME)?.takeIf { it.isNotBlank() }
            ?: "POS ERP Master"
        startForeground(NOTIFICATION_ID, buildNotification(deviceName))
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        @Suppress("DEPRECATION")
        stopForeground(true)
        super.onDestroy()
    }

    private fun buildNotification(deviceName: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("Master mode active")
            .setContentText("$deviceName is keeping local master services ready")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Master Host",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps POS ERP master services active while the app is backgrounded"
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "pos_erp_master_host"
        const val NOTIFICATION_ID = 18080
        const val EXTRA_DEVICE_NAME = "device_name"
        @Volatile var isRunning: Boolean = false
    }
}

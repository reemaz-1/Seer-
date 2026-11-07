package com.swe444.seer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app awake while the customer has an active order (#28).
 *
 * Android 14 and later freeze an app a few seconds after it goes to the
 * background, so it could not receive status updates. While this service runs,
 * a small fixed notification ("نتابع تحديثات طلبك") shows in the status
 * bar and Android keeps the app running, like driver and delivery apps.
 * Written from scratch, without packages or Firebase Cloud Messaging.
 */
class OrderUpdatesService : Service() {

    companion object {
        private const val CHANNEL_ID = "customer_order_tracking"
        private const val NOTIFICATION_ID = 4702

        fun start(context: Context) {
            val intent = Intent(context, OrderUpdatesService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, OrderUpdatesService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        // If Android kills the app, there is nothing left to listen with,
        // so the service is not restarted on its own.
        return START_NOT_STICKY
    }

    /** Swiping the app away from recent apps ends order updates mode. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    @Suppress("DEPRECATION")
    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager.getNotificationChannel(CHANNEL_ID) == null
        ) {
            // Low importance: shows quietly, with no sound or vibration.
            val channel = NotificationChannel(
                CHANNEL_ID,
                "متابعة الطلب",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "يظهر أثناء متابعة طلب خدمة نشط"
            manager.createNotificationChannel(channel)
        }

        val openApp = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val tap = PendingIntent.getActivity(
            this,
            1,
            openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("سَيْر")
            .setContentText("نتابع تحديثات طلبك")
            .setContentIntent(tap)
            .setOngoing(true)
            .build()
    }
}

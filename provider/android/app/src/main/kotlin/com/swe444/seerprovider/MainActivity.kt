package com.swe444.seerprovider

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Notifications for new requests (#47), written from scratch without
    // packages or Firebase Cloud Messaging. The Dart side
    // (lib/services/device_alerts.dart) calls these methods: it reads the
    // phone's mode and plays the tone or vibrates while the app is open, and
    // posts a system notification while the app is in the background.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seer/notification_sound"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "ringerMode" -> result.success(ringerMode())
                "playNotificationTone" -> result.success(playNotificationTone())
                "vibrate" -> result.success(vibrate())
                "showSystemNotification" -> result.success(
                    showSystemNotification(
                        call.argument<String>("title") ?: "",
                        call.argument<String>("body") ?: ""
                    )
                )
                "setAvailableMode" -> {
                    // Keeps the app listening in the background while the
                    // provider is available (see AvailabilityService.kt).
                    try {
                        if (call.argument<Boolean>("on") == true) {
                            AvailabilityService.start(this)
                        } else {
                            AvailabilityService.stop(this)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** The phone's current mode: "normal", "vibrate" or "silent". */
    private fun ringerMode(): String {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return when (audio.ringerMode) {
            AudioManager.RINGER_MODE_SILENT -> "silent"
            AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
            else -> "normal"
        }
    }

    /** Plays the user's own default notification tone. */
    private fun playNotificationTone(): Boolean {
        return try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
                ?: return false
            ringtone.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            ringtone.play()
            true
        } catch (e: Exception) {
            false
        }
    }

    /** One short vibration. */
    @Suppress("DEPRECATION")
    private fun vibrate(): Boolean {
        return try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (!vibrator.hasVibrator()) return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE)
                )
            } else {
                vibrator.vibrate(400)
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private val channelId = "new_requests"

    /** Creates the "new requests" channel once (Android 8 and later). */
    private fun ensureChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(channelId) != null) return
        val channel = NotificationChannel(
            channelId,
            "طلبات جديدة",
            NotificationManager.IMPORTANCE_HIGH
        )
        channel.description = "إشعار عند وصول طلب خدمة جديد"
        manager.createNotificationChannel(channel)
    }

    /**
     * Shows a notification in the status bar and on the lock screen.
     * Its sound and vibration follow the phone's mode automatically.
     * Tapping it opens the app.
     */
    @Suppress("DEPRECATION")
    private fun showSystemNotification(title: String, body: String): Boolean {
        return try {
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            ensureChannel(manager)

            val openApp = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val tap = PendingIntent.getActivity(
                this,
                0,
                openApp,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, channelId)
            } else {
                Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
                    .setDefaults(Notification.DEFAULT_ALL)
            }
            val notification = builder
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle(title)
                .setContentText(body)
                .setContentIntent(tap)
                .setAutoCancel(true)
                .setCategory(Notification.CATEGORY_MESSAGE)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .build()

            // A new id each time, so several requests show as several rows.
            manager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Asks for the notifications permission (Android 13 and later). */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < 33) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) return
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4701)
    }
}

package com.swe444.seer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
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
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // FCM uses this channel when Android displays a background/closed-app
        // notification. The foreground Firestore banner uses only its tone.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel("customer_order_updates") == null) {
                manager.createNotificationChannel(NotificationChannel(
                    "customer_order_updates", "تحديثات طلباتك", NotificationManager.IMPORTANCE_HIGH
                ).apply { description = "إشعار عند تغيّر حالة طلب الخدمة" })
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "seer/notification_sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ringerMode" -> {
                        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        result.success(when (audio.ringerMode) {
                            AudioManager.RINGER_MODE_SILENT -> "silent"
                            AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
                            else -> "normal"
                        })
                    }
                    "playNotificationTone" -> result.success(playTone())
                    "vibrate" -> result.success(vibrate())
                    else -> result.notImplemented()
                }
            }
    }

    private fun playTone(): Boolean = try {
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val tone = RingtoneManager.getRingtone(applicationContext, uri)
        if (tone == null) false else {
            tone.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
            tone.play()
            true
        }
    } catch (_: Exception) { false }

    @Suppress("DEPRECATION")
    private fun vibrate(): Boolean = try {
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        if (!vibrator.hasVibrator()) false else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))
            } else vibrator.vibrate(400)
            true
        }
    } catch (_: Exception) { false }
}

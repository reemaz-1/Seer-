package com.swe444.seerprovider

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
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration

/**
 * Keeps the app awake while the provider is "available" (#47).
 *
 * Android 14 and later freeze an app a few seconds after it goes to the
 * background, so it could not hear new requests. While this service runs,
 * a small fixed notification ("متاح لاستقبال الطلبات") shows in the status
 * bar and Android keeps the app running, like driver and delivery apps.
 *
 * The service also listens to the provider's notifications itself, so a new
 * request still shows on the phone after the provider swipes the app away
 * from recent apps. While the app screen exists, the Dart side shows the
 * notices instead, so each notice is shown once.
 * Written from scratch, without packages or Firebase Cloud Messaging.
 */
class AvailabilityService : Service() {

    companion object {
        private const val CHANNEL_ID = "availability"
        private const val NOTIFICATION_ID = 4702

        // Same channel as MainActivity's system notifications for requests.
        private const val NOTICES_CHANNEL_ID = "new_requests"

        // Notices older than this when the service starts are not shown again.
        private const val START_GRACE_MS = 60_000L

        fun start(context: Context) {
            val intent = Intent(context, AvailabilityService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AvailabilityService::class.java))
        }
    }

    private var listener: ListenerRegistration? = null
    private var startedAt = 0L

    /** Stops the service if the provider signs out while it runs. */
    private val authListener = FirebaseAuth.AuthStateListener { auth ->
        if (auth.currentUser == null) stopSelf()
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
        startListening()
        // The service listens by itself, so Android may restart it after
        // killing it for memory.
        return START_STICKY
    }

    override fun onDestroy() {
        listener?.remove()
        listener = null
        FirebaseAuth.getInstance().removeAuthStateListener(authListener)
        super.onDestroy()
    }

    /**
     * Starts listening to the signed-in provider's notifications, once.
     * Only notices added after the first result are shown, so old ones
     * do not show again.
     */
    private fun startListening() {
        if (listener != null) return
        val uid = FirebaseAuth.getInstance().currentUser?.uid
        if (uid == null) {
            stopSelf()
            return
        }
        FirebaseAuth.getInstance().addAuthStateListener(authListener)
        startedAt = System.currentTimeMillis()
        var first = true
        listener = FirebaseFirestore.getInstance()
            .collection("notifications")
            .whereEqualTo("recipientId", uid)
            .addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) return@addSnapshotListener
                if (first) {
                    first = false
                    return@addSnapshotListener
                }
                // While the app screen exists, the Dart side shows the notice.
                if (MainActivity.isOpen) return@addSnapshotListener
                for (change in snapshot.documentChanges) {
                    if (change.type == DocumentChange.Type.ADDED) {
                        showNotice(change.document)
                    }
                }
            }
    }

    /** Takes a notice document; shows it as a system notification if it is new. */
    @Suppress("DEPRECATION")
    private fun showNotice(doc: DocumentSnapshot) {
        if (doc.getBoolean("read") == true) return
        val title = doc.getString("title") ?: return
        val body = doc.getString("body") ?: ""
        // A notice saved before the service started was already handled.
        val createdAt = doc.getTimestamp("createdAt")?.toDate()?.time
        if (createdAt != null && createdAt < startedAt - START_GRACE_MS) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager.getNotificationChannel(NOTICES_CHANNEL_ID) == null
        ) {
            val channel = NotificationChannel(
                NOTICES_CHANNEL_ID,
                "طلبات جديدة",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "إشعار عند وصول طلب خدمة جديد"
            manager.createNotificationChannel(channel)
        }

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
            Notification.Builder(this, NOTICES_CHANNEL_ID)
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
        // The document id keeps one row per notice.
        manager.notify(doc.id.hashCode(), notification)
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
                "حالة التوفر",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "يظهر طول ما أنت متاح لاستقبال الطلبات"
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
            .setContentText("متاح لاستقبال الطلبات")
            .setContentIntent(tap)
            .setOngoing(true)
            .build()
    }
}

package com.xiaotai.life.monitor

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.xiaotai.life.MainActivity

/**
 * 强提醒前台服务。
 *
 * 只负责轮询后端强提醒并用悬浮窗展示，不采集、不上报设备页面内容或使用情况。
 */
class MonitorService : Service() {

    private var worker: HandlerThread? = null
    private var workerHandler: Handler? = null

    private val tickRunnable = object : Runnable {
        override fun run() {
            doTick()
            val interval = MonitorPrefs.pollIntervalSec(applicationContext) * 1000L
            workerHandler?.postDelayed(this, interval)
        }
    }

    override fun onCreate() {
        super.onCreate()
        startAsForeground()
        val thread = HandlerThread("xiaotai-force-push").also { it.start() }
        worker = thread
        workerHandler = Handler(thread.looper)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        workerHandler?.removeCallbacks(tickRunnable)
        workerHandler?.post(tickRunnable)
        return START_STICKY
    }

    override fun onDestroy() {
        workerHandler?.removeCallbacks(tickRunnable)
        worker?.quitSafely()
        worker = null
        workerHandler = null
        OverlayManager.dismiss()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun doTick() {
        val ctx = applicationContext
        if (!MonitorPrefs.hasConfig(ctx)) return

        val pending = MonitorHttpClient.pollPending(ctx)
        if (pending.isEmpty()) return

        val acked = MonitorPrefs.ackedIds(ctx)
        for (push in pending) {
            if (acked.contains(push.id)) continue
            OverlayManager.show(
                ctx,
                push.title,
                push.content,
                push.level,
                onConfirm = {
                    workerHandler?.post {
                        if (MonitorHttpClient.ack(ctx, push.id)) {
                            MonitorPrefs.addAckedId(ctx, push.id)
                        }
                    }
                },
                onUnavailable = {
                    workerHandler?.post {
                        if (MonitorHttpClient.ack(ctx, push.id)) {
                            MonitorPrefs.addAckedId(ctx, push.id)
                        }
                    }
                },
            )
            break
        }
    }

    private fun startAsForeground() {
        ensureChannel()
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, tapIntent, flags)

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("婷婷小笨笔记")
            .setContentText("后台提醒守护中")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setContentIntent(pendingIntent)
            .build()

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIF_ID, notification, type)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "提醒守护",
            NotificationManager.IMPORTANCE_MIN,
        ).apply {
            description = "用于保持提醒守护服务稳定运行"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "xiaotai_monitor_guard"
        private const val NOTIF_ID = 7301
        const val ACTION_STOP = "com.xiaotai.life.monitor.STOP"

        fun start(context: Context) {
            val intent = Intent(context, MonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, MonitorService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {
            }
        }
    }
}

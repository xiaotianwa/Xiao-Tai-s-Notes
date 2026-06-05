package com.xiaotai.life.monitor

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 开机/应用更新后，若用户此前已开启监控，则恢复前台服务。
 */
class MonitorBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }
        if (MonitorPrefs.isEnabled(context) && MonitorPrefs.hasConfig(context)) {
            MonitorService.start(context)
        }
    }
}

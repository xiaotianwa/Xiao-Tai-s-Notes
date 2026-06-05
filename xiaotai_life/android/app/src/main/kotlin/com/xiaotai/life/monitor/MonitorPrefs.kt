package com.xiaotai.life.monitor

import android.content.Context

/**
 * 监控服务的轻量配置存储。
 *
 * 由 Flutter 端在启动监控时写入（baseUrl / token / deviceId 等），
 * 前台 Service 与开机自启 Receiver 直接从这里读取，
 * 不依赖 Flutter engine 存活。
 */
object MonitorPrefs {
    private const val FILE = "xiaotai_monitor_prefs"

    private const val KEY_ENABLED = "enabled"
    private const val KEY_BASE_URL = "base_url"
    private const val KEY_AUTH_TOKEN = "auth_token"
    private const val KEY_DEVICE_ID = "device_id"
    private const val KEY_DEVICE_NAME = "device_name"
    private const val KEY_POLL_INTERVAL = "poll_interval_sec"
    private const val KEY_LAST_ACK = "last_ack_ids"

    private const val DEFAULT_POLL_INTERVAL = 20

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun isEnabled(context: Context): Boolean = prefs(context).getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    fun baseUrl(context: Context): String = prefs(context).getString(KEY_BASE_URL, "").orEmpty()

    fun authToken(context: Context): String = prefs(context).getString(KEY_AUTH_TOKEN, "").orEmpty()

    fun deviceId(context: Context): String = prefs(context).getString(KEY_DEVICE_ID, "").orEmpty()

    fun deviceName(context: Context): String =
        prefs(context).getString(KEY_DEVICE_NAME, "").orEmpty()

    fun pollIntervalSec(context: Context): Int =
        prefs(context).getInt(KEY_POLL_INTERVAL, DEFAULT_POLL_INTERVAL).coerceIn(10, 300)

    /** 更新 token（Flutter 前台时刷新 access token 后调用，避免后台轮询用过期 token）。 */
    fun updateAuthToken(context: Context, token: String) {
        prefs(context).edit().putString(KEY_AUTH_TOKEN, token).apply()
    }

    fun save(
        context: Context,
        baseUrl: String,
        authToken: String,
        deviceId: String,
        deviceName: String,
        pollIntervalSec: Int,
    ) {
        prefs(context).edit()
            .putBoolean(KEY_ENABLED, true)
            .putString(KEY_BASE_URL, baseUrl.trimEnd('/'))
            .putString(KEY_AUTH_TOKEN, authToken)
            .putString(KEY_DEVICE_ID, deviceId)
            .putString(KEY_DEVICE_NAME, deviceName)
            .putInt(KEY_POLL_INTERVAL, pollIntervalSec.coerceIn(10, 300))
            .apply()
    }

    /** 记录最近已弹出的强提醒 id，避免轮询重复弹窗（保留最近 50 条）。 */
    fun ackedIds(context: Context): MutableSet<String> {
        val raw = prefs(context).getString(KEY_LAST_ACK, "").orEmpty()
        if (raw.isBlank()) return mutableSetOf()
        return raw.split(',').filter { it.isNotBlank() }.toMutableSet()
    }

    fun addAckedId(context: Context, id: String) {
        val set = ackedIds(context)
        set.add(id)
        val trimmed = set.toList().takeLast(50)
        prefs(context).edit().putString(KEY_LAST_ACK, trimmed.joinToString(",")).apply()
    }

    fun hasConfig(context: Context): Boolean =
        baseUrl(context).isNotBlank() && deviceId(context).isNotBlank()
}

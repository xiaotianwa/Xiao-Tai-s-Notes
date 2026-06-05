package com.xiaotai.life.monitor

import android.content.Context
import org.json.JSONObject
import java.io.BufferedReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/** 待强弹的提醒。 */
data class ForcePush(
    val id: String,
    val title: String,
    val content: String,
    val level: String,
)

/**
 * 强提醒服务网络层。
 *
 * 只轮询和确认强提醒，不上传设备使用情况。
 */
object MonitorHttpClient {
    private const val CONNECT_TIMEOUT = 8000
    private const val READ_TIMEOUT = 10000

    private fun open(context: Context, path: String, method: String): HttpURLConnection? {
        val base = MonitorPrefs.baseUrl(context)
        if (base.isBlank()) return null
        val url = URL("$base$path")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = method
        conn.connectTimeout = CONNECT_TIMEOUT
        conn.readTimeout = READ_TIMEOUT
        conn.setRequestProperty("Accept", "application/json")
        val token = MonitorPrefs.authToken(context)
        if (token.isNotBlank()) {
            conn.setRequestProperty("Authorization", "Bearer $token")
        }
        return conn
    }

    private fun readBody(conn: HttpURLConnection): String {
        val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
        return stream?.bufferedReader()?.use(BufferedReader::readText).orEmpty()
    }

    /** 轮询待强弹的提醒列表。 */
    fun pollPending(context: Context): List<ForcePush> {
        val deviceId = MonitorPrefs.deviceId(context)
        val encodedDeviceId = URLEncoder.encode(deviceId, Charsets.UTF_8.name())
        val conn = open(context, "/monitor/push/pending?deviceId=$encodedDeviceId", "GET")
            ?: return emptyList()
        return try {
            if (conn.responseCode !in 200..299) return emptyList()
            val body = readBody(conn)
            val json = JSONObject(body)
            val data = json.optJSONArray("data") ?: return emptyList()
            val list = mutableListOf<ForcePush>()
            for (i in 0 until data.length()) {
                val item = data.optJSONObject(i) ?: continue
                val id = item.optString("id")
                if (id.isBlank()) continue
                list.add(
                    ForcePush(
                        id = id,
                        title = item.optString("title", "提醒"),
                        content = item.optString("content", ""),
                        level = item.optString("level", "info"),
                    ),
                )
            }
            list
        } catch (_: Exception) {
            emptyList()
        } finally {
            conn.disconnect()
        }
    }

    /** 确认某条强提醒已送达/已弹出，避免重复推送。 */
    fun ack(context: Context, id: String): Boolean {
        val conn = open(context, "/monitor/push/ack", "POST") ?: return false
        return try {
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json")
            val payload = JSONObject().apply {
                put("deviceId", MonitorPrefs.deviceId(context))
                put("id", id)
            }
            conn.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
            conn.responseCode in 200..299
        } catch (_: Exception) {
            false
        } finally {
            conn.disconnect()
        }
    }
}

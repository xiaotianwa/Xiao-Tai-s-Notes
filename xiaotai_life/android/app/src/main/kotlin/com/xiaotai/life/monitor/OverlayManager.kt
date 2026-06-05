package com.xiaotai.life.monitor

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * 系统级悬浮窗：在任意应用之上强弹弹窗。
 *
 * 需要用户在「设置 > 显示在其他应用上层」中授予 SYSTEM_ALERT_WINDOW。
 */
object OverlayManager {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var rootView: View? = null

    fun canDrawOverlays(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    /** 在主线程展示一个强弹弹窗。level: info / warn / critical 决定主色。 */
    fun show(
        context: Context,
        title: String,
        content: String,
        level: String,
        onConfirm: () -> Unit,
        onUnavailable: () -> Unit,
    ) {
        mainHandler.post {
            showInternal(context.applicationContext, title, content, level, onConfirm, onUnavailable)
        }
    }

    fun dismiss() {
        mainHandler.post { dismissInternal(currentWindowManager) }
    }

    private var currentWindowManager: WindowManager? = null

    private fun showInternal(
        context: Context,
        title: String,
        content: String,
        level: String,
        onConfirm: () -> Unit,
        onUnavailable: () -> Unit,
    ) {
        if (!canDrawOverlays(context)) {
            onUnavailable()
            return
        }
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
        if (wm == null) {
            onUnavailable()
            return
        }
        currentWindowManager = wm
        dismissInternal(wm)

        val accent = when (level) {
            "critical" -> Color.parseColor("#E5484D")
            "warn" -> Color.parseColor("#F5A524")
            else -> Color.parseColor("#E08A5B")
        }

        val scrim = FrameLayout(context).apply {
            setBackgroundColor(Color.parseColor("#99000000"))
        }

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 22f)
                setColor(Color.parseColor("#FFFBF5"))
            }
            setPadding(dp(context, 22f).toInt(), dp(context, 22f).toInt(),
                dp(context, 22f).toInt(), dp(context, 18f).toInt())
        }

        val titleView = TextView(context).apply {
            text = title
            setTextColor(accent)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 19f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
        val contentView = TextView(context).apply {
            text = content
            setTextColor(Color.parseColor("#5A4632"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setPadding(0, dp(context, 12f).toInt(), 0, dp(context, 18f).toInt())
        }
        val okButton = Button(context).apply {
            text = "知道了"
            setTextColor(Color.WHITE)
            isAllCaps = false
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 14f)
                setColor(accent)
            }
            setOnClickListener {
                dismissInternal(wm)
                onConfirm()
            }
        }

        card.addView(
            titleView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        card.addView(
            contentView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        card.addView(
            okButton,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(context, 46f).toInt(),
            ),
        )

        val cardParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            gravity = Gravity.CENTER
            marginStart = dp(context, 28f).toInt()
            marginEnd = dp(context, 28f).toInt()
        }
        scrim.addView(card, cardParams)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            android.graphics.PixelFormat.TRANSLUCENT,
        )

        try {
            wm.addView(scrim, params)
            rootView = scrim
        } catch (_: Exception) {
            rootView = null
            onUnavailable()
        }
    }

    private fun dismissInternal(wm: WindowManager?) {
        val view = rootView ?: return
        rootView = null
        try {
            wm?.removeView(view)
        } catch (_: Exception) {
        }
    }

    private fun dp(context: Context, value: Float): Float {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            context.resources.displayMetrics,
        )
    }
}

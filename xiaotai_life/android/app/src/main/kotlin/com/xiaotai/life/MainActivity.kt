package com.xiaotai.life

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.xiaotai.life.monitor.MonitorPrefs
import com.xiaotai.life.monitor.MonitorService
import com.xiaotai.life.monitor.OverlayManager
import java.io.File
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val mediaPickerChannel = "xiaotai_life/media_picker"
    private val appInstallerChannel = "xiaotai_life/app_installer"
    private val deviceInfoChannel = "xiaotai_life/device_info"
    private val monitorChannel = "xiaotai_life/monitor"
    private val speechChannel = "xiaotai_life/speech"
    private val pickImagesRequestCode = 4317
    private val speechRequestCode = 4319
    private val audioPermissionRequestCode = 4320
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingSpeechResult: MethodChannel.Result? = null
    private var pendingAudioPermissionResult: MethodChannel.Result? = null
    private var pendingSilentSpeechResult: MethodChannel.Result? = null
    private var silentSpeechRecognizer: SpeechRecognizer? = null
    private val silentSpeechHandler = Handler(Looper.getMainLooper())
    private var silentSpeechBestText = ""
    private var silentSpeechStopRequested = false
    private val silentSpeechTimeout = Runnable {
        silentSpeechStopRequested = true
        try {
            silentSpeechRecognizer?.stopListening()
        } catch (_: Exception) {
        }
        silentSpeechHandler.postDelayed(silentSpeechForceFinish, 3000L)
    }
    private val silentSpeechForceFinish = Runnable {
        finishSilentSpeech(success = true, text = silentSpeechBestText)
    }
    private var maxImageCount = 3

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            mediaPickerChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickImages" -> handlePickImages(call.argument<Int>("maxCount") ?: 3, result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            appInstallerChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> handleInstallApk(call.argument<String>("path"), result)
                "openInstallPermissionSettings" -> {
                    openInstallPermissionSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceInfoChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "deviceName" -> result.success(androidDeviceName())
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            monitorChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlays" -> result.success(OverlayManager.canDrawOverlays(this))
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" ->
                    result.success(isIgnoringBatteryOptimizations())
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(null)
                }
                "start" -> handleStartMonitor(call, result)
                "stop" -> {
                    MonitorPrefs.setEnabled(applicationContext, false)
                    MonitorService.stop(applicationContext)
                    result.success(true)
                }
                "updateToken" -> {
                    val token = call.argument<String>("token").orEmpty()
                    MonitorPrefs.updateAuthToken(applicationContext, token)
                    result.success(true)
                }
                "isEnabled" -> result.success(MonitorPrefs.isEnabled(applicationContext))
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            speechChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "ensureAppAudioPermission" -> handleRequestAudioPermission(result)
                "engineHasAudioPermission" ->
                    result.success(speechEngineHasAudioPermission())
                "openEngineSettings" -> {
                    openSpeechEngineSettings()
                    result.success(null)
                }
                "recognizeSilent" -> handleRecognizeSilent(result)
                "stopSilent" -> {
                    finishSilentSpeech(success = true, text = silentSpeechBestText)
                    result.success(null)
                }
                "recognize" -> handleRecognizeSpeech(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleRequestAudioPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingAudioPermissionResult != null) {
            result.error("busy", "audio permission request is running", null)
            return
        }
        pendingAudioPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            audioPermissionRequestCode
        )
    }

    private fun handleRecognizeSilent(result: MethodChannel.Result) {
        if (pendingSilentSpeechResult != null) {
            result.error("busy", "语音识别正在进行中", null)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error("unavailable", "系统语音识别不可用", null)
            return
        }
        pendingSilentSpeechResult = result
        silentSpeechBestText = ""
        silentSpeechStopRequested = false
        silentSpeechRecognizer?.destroy()
        silentSpeechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) = Unit
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() = Unit
                override fun onEvent(eventType: Int, params: Bundle?) = Unit

                override fun onPartialResults(partialResults: Bundle?) {
                    updateSilentSpeechBestText(partialResults)
                }

                override fun onResults(results: Bundle?) {
                    updateSilentSpeechBestText(results)
                    finishSilentSpeech(success = true, text = silentSpeechBestText)
                }

                override fun onError(error: Int) {
                    val text = silentSpeechBestText
                    if (text.isNotBlank()) {
                        finishSilentSpeech(success = true, text = text)
                    } else if (silentSpeechStopRequested) {
                        finishSilentSpeech(success = true, text = "")
                    } else {
                        finishSilentSpeech(
                            success = false,
                            code = "recognition_error_$error",
                            message = "语音识别失败：$error"
                        )
                    }
                }
            })
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.SIMPLIFIED_CHINESE.toLanguageTag())
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE,
                Locale.SIMPLIFIED_CHINESE.toLanguageTag()
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1800L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2600L)
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                2600L
            )
        }
        try {
            silentSpeechHandler.postDelayed(silentSpeechTimeout, 18000L)
            silentSpeechRecognizer?.startListening(intent)
        } catch (error: Exception) {
            finishSilentSpeech(
                success = false,
                code = "start_failed",
                message = error.message ?: "语音识别启动失败"
            )
        }
    }

    private fun updateSilentSpeechBestText(results: Bundle?) {
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val text = matches?.firstOrNull().orEmpty().trim()
        if (text.isNotBlank()) {
            silentSpeechBestText = text
        }
    }

    private fun finishSilentSpeech(
        success: Boolean,
        text: String = "",
        code: String = "recognition_failed",
        message: String = "语音识别失败"
    ) {
        silentSpeechHandler.removeCallbacks(silentSpeechTimeout)
        silentSpeechHandler.removeCallbacks(silentSpeechForceFinish)
        try {
            silentSpeechRecognizer?.cancel()
            silentSpeechRecognizer?.destroy()
        } catch (_: Exception) {
        }
        silentSpeechRecognizer = null
        val result = pendingSilentSpeechResult ?: return
        pendingSilentSpeechResult = null
        if (success) {
            result.success(text)
        } else {
            result.error(code, message, null)
        }
    }

    private fun handleRecognizeSpeech(result: MethodChannel.Result) {
        if (!speechEngineHasAudioPermission()) {
            result.error(
                "engine_permission_denied",
                "系统语音引擎缺少麦克风权限",
                speechEnginePackageName()
            )
            return
        }
        if (pendingSpeechResult != null) {
            result.error("busy", "语音识别正在进行中", null)
            return
        }
        pendingSpeechResult = result
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, false)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_PROMPT, "请说出想记录或想问的内容")
        }
        try {
            startActivityForResult(intent, speechRequestCode)
        } catch (error: Exception) {
            pendingSpeechResult = null
            result.error("unavailable", error.message, null)
        }
    }

    private fun speechEnginePackageName(): String? {
        val service = Settings.Secure.getString(
            contentResolver,
            "voice_recognition_service"
        ) ?: Settings.Secure.getString(contentResolver, "recognition_service")
        return ComponentName.unflattenFromString(service.orEmpty())?.packageName
    }

    private fun speechEngineHasAudioPermission(): Boolean {
        val packageName = speechEnginePackageName() ?: return true
        return packageManager.checkPermission(
            Manifest.permission.RECORD_AUDIO,
            packageName
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun openSpeechEngineSettings() {
        val packageName = speechEnginePackageName() ?: return
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun handleStartMonitor(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        val baseUrl = call.argument<String>("baseUrl").orEmpty()
        val deviceId = call.argument<String>("deviceId").orEmpty()
        if (baseUrl.isBlank() || deviceId.isBlank()) {
            result.error("invalid_argument", "baseUrl 和 deviceId 不能为空", null)
            return
        }
        MonitorPrefs.save(
            applicationContext,
            baseUrl = baseUrl,
            authToken = call.argument<String>("token").orEmpty(),
            deviceId = deviceId,
            deviceName = call.argument<String>("deviceName").orEmpty(),
            pollIntervalSec = call.argument<Int>("pollIntervalSec") ?: 20,
        )
        MonitorService.start(applicationContext)
        result.success(true)
    }

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val intent = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:$packageName")
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun handleInstallApk(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("invalid_argument", "APK 路径不能为空", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            result.error("install_permission_required", "需要允许此来源安装应用", null)
            return
        }
        val apkFile = File(path)
        if (!apkFile.exists()) {
            result.error("not_found", "APK 文件不存在", null)
            return
        }
        try {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                apkFile
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("install_failed", error.message, null)
        }
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName")
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun androidDeviceName(): String {
        val manufacturer = Build.MANUFACTURER.orEmpty().trim()
        val model = Build.MODEL.orEmpty().trim()
        if (manufacturer.isEmpty()) return model.ifEmpty { "Android 设备" }
        if (model.isEmpty()) return manufacturer
        return if (model.lowercase(Locale.getDefault())
                .contains(manufacturer.lowercase(Locale.getDefault()))
        ) {
            model
        } else {
            "$manufacturer $model"
        }
    }

    private fun handlePickImages(rawMax: Int, result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("busy", "图片选择器正在打开", null)
            return
        }
        maxImageCount = rawMax.coerceIn(1, 3)
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, maxImageCount > 1)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        try {
            startActivityForResult(
                Intent.createChooser(intent, "选择图片"),
                pickImagesRequestCode
            )
        } catch (error: Exception) {
            pendingPickResult = null
            result.error("unavailable", error.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == speechRequestCode) {
            val result = pendingSpeechResult ?: return
            pendingSpeechResult = null
            if (resultCode != Activity.RESULT_OK || data == null) {
                result.success("")
                return
            }
            val matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            result.success(matches?.firstOrNull().orEmpty())
            return
        }
        if (requestCode != pickImagesRequestCode) {
            return
        }

        val result = pendingPickResult ?: return
        pendingPickResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        try {
            val uris = mutableListOf<Uri>()
            val clipData = data.clipData
            if (clipData != null) {
                val count = minOf(clipData.itemCount, maxImageCount)
                for (index in 0 until count) {
                    uris.add(clipData.getItemAt(index).uri)
                }
            } else {
                data.data?.let { uris.add(it) }
            }

            val paths = uris
                .take(maxImageCount)
                .mapIndexedNotNull { index, uri -> copyPickedImage(uri, index) }
            result.success(paths)
        } catch (error: Exception) {
            result.error("copy_failed", error.message, null)
        }
    }

    private fun copyPickedImage(uri: Uri, index: Int): String? {
        val imageDir = File(filesDir, "entry_images").apply { mkdirs() }
        val imageFile = File(imageDir, "entry_${System.currentTimeMillis()}_$index.jpg")
        val input = contentResolver.openInputStream(uri) ?: return null
        input.use { source ->
            imageFile.outputStream().use { target ->
                source.copyTo(target)
            }
        }
        return imageFile.absolutePath
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != audioPermissionRequestCode) {
            return
        }
        val result = pendingAudioPermissionResult ?: return
        pendingAudioPermissionResult = null
        result.success(
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
        )
    }
}

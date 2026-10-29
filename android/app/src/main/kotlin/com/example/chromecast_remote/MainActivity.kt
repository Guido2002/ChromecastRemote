package com.example.chromecast_remote

import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import com.google.android.gms.cast.MediaStatus
import com.google.android.gms.cast.framework.CastContext
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var navigation: MethodChannel? = null
    private var pendingRemote = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chromecast_remote/cast_capabilities")
            .setMethodCallHandler { call, result ->
                if (call.method != "read") { result.notImplemented() }
                else {
                    try {
                        val session = CastContext.getSharedInstance(this).sessionManager.currentCastSession
                        val status = session?.remoteMediaClient?.mediaStatus
                        result.success(if (session == null || status == null) null else mapOf(
                            "deviceId" to session.castDevice?.deviceId,
                            "mediaSessionId" to status.toJson().optLong("mediaSessionId", -1L),
                            "seek" to status.isMediaCommandSupported(MediaStatus.COMMAND_SEEK),
                            "pause" to status.isMediaCommandSupported(MediaStatus.COMMAND_PAUSE)
                        ))
                    } catch (_: Exception) { result.success(null) }
                }
            }
        pendingRemote = intent?.action == ACTION_OPEN_REMOTE
        navigation = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chromecast_remote/navigation")
        navigation?.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeOpenRemote" -> {
                    result.success(pendingRemote)
                    pendingRemote = false
                }
                "addQuickSettingsTile" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        getSystemService(StatusBarManager::class.java).requestAddTileService(
                            ComponentName(this, RemoteTileService::class.java),
                            "TV remote", Icon.createWithResource(this, R.drawable.ic_remote_tile),
                            mainExecutor
                        ) { result.success(it) }
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ACTION_OPEN_REMOTE) {
            pendingRemote = true
            navigation?.invokeMethod("openRemote", null)
        }
    }

    companion object {
        const val ACTION_OPEN_REMOTE = "com.example.chromecast_remote.OPEN_REMOTE"
    }
}

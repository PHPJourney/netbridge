package com.netbridge.netbridge

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import obfs2bridge.Obfs2bridge

class MainActivity : FlutterActivity() {
    private val channelName = "netbridge/obfs2"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            val serverAddrs = call.argument<String>("serverAddrs") ?: ""
                            val pskHex = call.argument<String>("psk") ?: ""
                            val localUdp =
                                (call.argument<Number>("localUdp")?.toLong() ?: 51822L)
                            val insecure = call.argument<Boolean>("insecure") ?: false
                            val channels =
                                (call.argument<Number>("channels")?.toLong() ?: 4L)
                            Obfs2bridge.start(
                                serverAddrs, pskHex, localUdp, insecure, channels
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("obfs2_start_failed", e.message, null)
                        }
                    }
                    "stop" -> {
                        Obfs2bridge.stop()
                        result.success(true)
                    }
                    "running" -> {
                        result.success(Obfs2bridge.running())
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

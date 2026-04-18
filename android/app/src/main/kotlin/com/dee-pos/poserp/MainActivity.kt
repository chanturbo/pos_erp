package com.dee_pos.poserp

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "pos_erp/master_runtime"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMasterHost" -> {
                        val deviceName =
                            call.argument<String>("deviceName") ?: "POS ERP Master"
                        startMasterHost(deviceName)
                        result.success(true)
                    }

                    "stopMasterHost" -> {
                        stopService(Intent(this, MasterHostService::class.java))
                        result.success(true)
                    }

                    "isMasterHostRunning" -> {
                        result.success(MasterHostService.isRunning)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun startMasterHost(deviceName: String) {
        val intent = Intent(this, MasterHostService::class.java).apply {
            putExtra(MasterHostService.EXTRA_DEVICE_NAME, deviceName)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}

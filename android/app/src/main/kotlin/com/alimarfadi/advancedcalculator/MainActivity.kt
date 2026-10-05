package com.alimarfadi.advancedcalculator

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    private var track: AudioTrack? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "advanced_calculator/cue")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "beep" -> { playBeep(); result.success(null) }
                    "vibrate" -> { vibrate(); result.success(null) }
                    "stop" -> { stopBeep(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    /** Short synthesized 880 Hz tone with a Hann window. No audio file is shipped. */
    private fun playBeep() {
        try {
            stopBeep()
            val sampleRate = 44100
            val count = (sampleRate * 0.14).toInt()
            val samples = ShortArray(count)
            for (i in 0 until count) {
                val t = i.toDouble() / sampleRate
                val window = 0.5 - 0.5 * cos(2 * PI * i / (count - 1))
                samples[i] = (sin(2 * PI * 880.0 * t) * 0.9 * window * Short.MAX_VALUE).toInt().toShort()
            }
            val audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setTransferMode(AudioTrack.MODE_STATIC)
                .setBufferSizeInBytes(count * 2)
                .build()
            audioTrack.write(samples, 0, count)
            audioTrack.play()
            track = audioTrack
        } catch (_: Exception) {
        }
    }

    private fun stopBeep() {
        try {
            track?.stop()
        } catch (_: Exception) {
        }
        track?.release()
        track = null
    }

    private fun vibrate() {
        try {
            val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            vibrator?.vibrate(VibrationEffect.createOneShot(120, VibrationEffect.DEFAULT_AMPLITUDE))
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        stopBeep()
        super.onDestroy()
    }
}

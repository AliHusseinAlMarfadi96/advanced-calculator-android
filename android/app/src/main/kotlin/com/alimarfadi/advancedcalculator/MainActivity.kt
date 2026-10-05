package com.alimarfadi.advancedcalculator

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    private var track: AudioTrack? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var speechResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var speechTimeoutRunnable: Runnable? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "advanced_calculator/speech")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listenOnce" -> {
                        val localeId = call.argument<String>("localeId") ?: "ar-SA"
                        val timeoutMs = call.argument<Number>("timeoutMs")?.toLong() ?: 25000L
                        startSpeechOnce(localeId, timeoutMs, result)
                    }
                    "cancel" -> {
                        cancelSpeech()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startSpeechOnce(localeId: String, timeoutMs: Long, result: MethodChannel.Result) {
        if (speechResult != null) {
            result.error("busy", "Speech recognition already in progress", null)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error("unavailable", "SpeechRecognizer not available", null)
            return
        }
        speechResult = result
        try {
            cancelSpeechInternal(releaseOnly = true)
            val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
            speechRecognizer = recognizer
            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onError(error: Int) {
                    finishSpeechError("error_$error")
                }
                override fun onResults(results: Bundle?) {
                    val texts = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val best = texts?.firstOrNull()?.trim().orEmpty()
                    finishSpeechSuccess(if (best.isEmpty()) null else best)
                }
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeId.replace('_', '-'))
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
            }
            recognizer.startListening(intent)

            speechTimeoutRunnable = Runnable {
                finishSpeechError("timeout")
            }
            mainHandler.postDelayed(speechTimeoutRunnable!!, timeoutMs)
        } catch (e: Exception) {
            finishSpeechError(e.message ?: "start_failed")
        }
    }

    private fun finishSpeechSuccess(text: String?) {
        mainHandler.post {
            clearSpeechTimeout()
            val pending = speechResult
            speechResult = null
            cancelSpeechInternal(releaseOnly = true)
            pending?.success(text)
        }
    }

    private fun finishSpeechError(code: String) {
        mainHandler.post {
            clearSpeechTimeout()
            val pending = speechResult
            speechResult = null
            cancelSpeechInternal(releaseOnly = true)
            // Return null on soft failures so Dart can retry / show Arabic status.
            if (code == "timeout" || code.startsWith("error_")) {
                pending?.success(null)
            } else {
                pending?.error(code, code, null)
            }
        }
    }

    private fun cancelSpeech() {
        clearSpeechTimeout()
        val pending = speechResult
        speechResult = null
        cancelSpeechInternal(releaseOnly = false)
        pending?.success(null)
    }

    private fun cancelSpeechInternal(releaseOnly: Boolean) {
        try {
            speechRecognizer?.cancel()
        } catch (_: Exception) {
        }
        try {
            speechRecognizer?.destroy()
        } catch (_: Exception) {
        }
        speechRecognizer = null
        if (!releaseOnly) {
            // already cleared pending in cancelSpeech
        }
    }

    private fun clearSpeechTimeout() {
        speechTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        speechTimeoutRunnable = null
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
        clearSpeechTimeout()
        cancelSpeechInternal(releaseOnly = false)
        speechResult = null
        stopBeep()
        super.onDestroy()
    }
}

package com.example.cspi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat

/**
 * 알람 소리/진동을 재생하는 포그라운드 서비스.
 * 화면(AlarmActivity) 표시 권한과 무관하게 소리/진동을 보장한다.
 * AlarmActivity가 뜨면 그 화면에서 "종료/스누즈"로 이 서비스를 멈춘다.
 */
class AlarmService : Service() {

    companion object {
        const val CHANNEL_ID = "cspi_alarm_service"
        const val NOTI_ID = 7002
        var isRunning = false

        fun start(context: Context, label: String, shift: String) {
            val intent = Intent(context, AlarmService::class.java).apply {
                putExtra("ALARM_LABEL", label)
                putExtra("ALARM_SHIFT", shift)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AlarmService::class.java))
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val label = intent?.getStringExtra("ALARM_LABEL") ?: "근무 기상 알람!"
        val shift = intent?.getStringExtra("ALARM_SHIFT") ?: "D"

        startForeground(NOTI_ID, buildNotification(label, shift))
        startSound()
        startVibration()

        // 다른 앱 사용 중/포그라운드 상태에서도 알람 화면을 강제로 띄움
        // (포그라운드 서비스는 백그라운드 startActivity 제한의 예외)
        try {
            val fullScreen = Intent(this, AlarmActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK or
                        Intent.FLAG_ACTIVITY_NO_USER_ACTION
                putExtra("ALARM_LABEL", label)
                putExtra("ALARM_SHIFT", shift)
            }
            startActivity(fullScreen)
        } catch (e: Exception) {
            // 혹시 막히면 알림의 fullScreenIntent가 대신 처리
        }

        isRunning = true
        return START_STICKY
    }

    private fun buildNotification(label: String, shift: String): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID, "근무 기상 알람",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "근무 시작 전 기상 알람"
                    setBypassDnd(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    setSound(null, null)  // 소리는 서비스가 직접 재생
                    enableVibration(false) // 진동도 서비스가 직접
                }
                nm.createNotificationChannel(channel)
            }
        }

        // 알람 화면을 여는 인텐트 (풀스크린 + 탭)
        val fullScreenIntent = Intent(this, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or
                    Intent.FLAG_ACTIVITY_NO_USER_ACTION
            putExtra("ALARM_LABEL", label)
            putExtra("ALARM_SHIFT", shift)
        }
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        val fullScreenPi = PendingIntent.getActivity(this, 7001, fullScreenIntent, piFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("근무 기상 시간")
            .setContentText(label)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullScreenPi, true)
            .setContentIntent(fullScreenPi)
            .build()
    }

    private fun startSound() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val soundEnabled = prefs.getBoolean("flutter.alarm_sound_on", true)
            if (!soundEnabled) return

            val saved = prefs.getString("flutter.alarm_ringtone_uri", null)
            val uri: Uri = if (!saved.isNullOrEmpty()) Uri.parse(saved)
                else RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

            val vol = try {
                when (val v = prefs.all["flutter.alarm_volume"]) {
                    is Double -> v.toFloat(); is Long -> v.toFloat(); is Int -> v.toFloat(); else -> 1.0f
                }
            } catch (e: Exception) { 1.0f }

            mediaPlayer = MediaPlayer().apply {
                setDataSource(this@AlarmService, uri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                setVolume(vol, vol)
                prepare()
                start()
            }
        } catch (e: Exception) { }
    }

    private fun startVibration() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val vibrateOn = prefs.getBoolean("flutter.alarm_vibrate_on", true)
            if (!vibrateOn) return

            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            val pattern = longArrayOf(0, 800, 400, 800, 400, 800)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) { }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        try { mediaPlayer?.stop(); mediaPlayer?.release(); mediaPlayer = null } catch (e: Exception) { }
        try { vibrator?.cancel(); vibrator = null } catch (e: Exception) { }
    }
}

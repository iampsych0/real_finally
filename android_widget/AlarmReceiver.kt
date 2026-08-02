package com.example.cspi

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            // 재부팅 완료: 다음 알람 정확히 재등록 (삼성/HTC 등 OEM 변종 액션 포함)
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                AlarmScheduler.rescheduleOnBoot(context)
            }

            // 자정 트리거: 내일 근무 알람 재등록
            "com.example.cspi.SET_DAILY_ALARM" -> {
                AlarmScheduler.scheduleNextDayAlarm(context)
                DailyAlarmManager.scheduleMidnightTrigger(context)
            }

            // 실제 기상 시각에 도달 → 풀스크린 알람 발생
            "com.example.cspi.WAKE_UP_ALARM" -> {
                val label = intent.getStringExtra("ALARM_LABEL") ?: "근무 기상 알람!"
                val shift = intent.getStringExtra("ALARM_SHIFT") ?: "D"
                fireAlarm(context, label, shift)
            }
        }
    }

    private fun fireAlarm(context: Context, label: String, shift: String) {
        // 포그라운드 서비스가 소리/진동/풀스크린 알림을 모두 담당
        // → 화면 표시 권한과 무관하게 소리·진동 보장
        AlarmService.start(context, label, shift)
    }
}

// 매일 자정 트리거 관리
object DailyAlarmManager {
    private const val REQUEST_CODE = 9999

    fun scheduleMidnightTrigger(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.example.cspi.SET_DAILY_ALARM"
        }
        val pi = PendingIntent.getBroadcast(
            context, REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val cal = java.util.Calendar.getInstance().apply {
            add(java.util.Calendar.DAY_OF_YEAR, 1)
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 1)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi
            )
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
        }
    }

    fun cancelMidnightTrigger(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.example.cspi.SET_DAILY_ALARM"
        }
        val pi = PendingIntent.getBroadcast(
            context, REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pi)
    }
}

package com.example.cspi

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.time.LocalDate
import java.util.Calendar

object AlarmScheduler {

    // 알람을 식별할 고정 ID (이 값이 같아야 새로 생성 안 되고 기존 알람이 수정됨)
    private const val ALARM_REQUEST_CODE = 8888

    private fun readInt(prefs: android.content.SharedPreferences, key: String, default: Int): Int {
        return when (val v = prefs.all[key]) {
            is Int  -> v
            is Long -> v.toInt()
            else    -> default
        }
    }

    fun getWakeTime(context: Context, shift: String): Pair<Int, Int>? {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return when (shift) {
            "D"  -> Pair(readInt(prefs, "flutter.alarm_d_hour", 6),
                         readInt(prefs, "flutter.alarm_d_min", 30))
            "S"  -> Pair(readInt(prefs, "flutter.alarm_s_hour", 10),
                         readInt(prefs, "flutter.alarm_s_min", 0))
            "G"  -> Pair(readInt(prefs, "flutter.alarm_g_hour", 21),
                         readInt(prefs, "flutter.alarm_g_min", 0))
            "DS" -> Pair(readInt(prefs, "flutter.alarm_ds_hour", 6),
                         readInt(prefs, "flutter.alarm_ds_min", 30))
            else -> null
        }
    }

    // 💡 별도 매니페스트 권한 없이 백그라운드에서 안전하게 작동하는 알람 설정
    fun setAlarm(context: Context, hour: Int, minute: Int, label: String, shift: String = "D") {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.example.cspi.WAKE_UP_ALARM"
            putExtra("ALARM_LABEL", label)
            putExtra("ALARM_SHIFT", shift)
        }

        // FLAG_UPDATE_CURRENT로 기존 알람 ID(8888)를 계속 덮어씀
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pi = PendingIntent.getBroadcast(context, ALARM_REQUEST_CODE, intent, flags)

        // 알람 시간 세팅: 오늘 해당 시각이 아직 안 지났으면 오늘, 지났으면 내일
        val now = Calendar.getInstance()
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        // scheduleNextDayAlarm에서 넘어온 "내일 근무" 예약은 항상 내일이어야 하므로
        // 여기서는 지난 시각이면 하루 더함 (오늘 지났으면 자연히 내일이 됨)
        if (calendar.timeInMillis <= now.timeInMillis) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }

        // 정확한 시각에 울리도록 예약 (SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM 권한 이미 선언됨)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pi
                )
            } catch (e: SecurityException) {
                // 정확 알람 권한이 없는 경우 폴백
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pi
                )
            }
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pi
            )
        }
    }

    // 테스트용: 지정한 초 뒤에 즉시 알람을 울림 (내일까지 기다릴 필요 없음)
    fun setTestAlarm(context: Context, secondsFromNow: Int = 5, shift: String = "D") {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val shiftName = when (shift) {
            "D" -> "주간"; "S" -> "저녁"; "G" -> "야간"; "DS" -> "주간+저녁"; else -> shift
        }
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.example.cspi.WAKE_UP_ALARM"
            putExtra("ALARM_LABEL", "${shiftName} 근무 테스트 알람")
            putExtra("ALARM_SHIFT", shift)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        val pi = PendingIntent.getBroadcast(context, ALARM_REQUEST_CODE, intent, flags)
        val triggerAt = System.currentTimeMillis() + secondsFromNow * 1000L
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } catch (e: SecurityException) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }

    // 그날 근무의 기상 시각으로 알람 예약 (override 반영)
    // 오늘 기상 시각이 안 지났으면 오늘, 지났으면 다음 근무일로
    fun scheduleNextDayAlarm(context: Context) {
        scheduleUpcomingAlarm(context)
    }

    fun rescheduleOnBoot(context: Context) {
        scheduleUpcomingAlarm(context)
        DailyAlarmManager.scheduleMidnightTrigger(context)
    }

    // 핵심: 다음에 울려야 할 "그날 근무" 알람을 찾아 예약
    fun scheduleUpcomingAlarm(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val team = prefs.getString("flutter.my_team", "B") ?: "B"
        val alarmEnabled = prefs.getBoolean("flutter.alarm_enabled", true)
        if (!alarmEnabled) {
            cancelAlarm(context)
            return
        }

        val now = Calendar.getInstance()

        // 오늘부터 최대 14일 앞까지 훑어서, 가장 가까운 "근무일 + 기상시각 미도래" 찾기
        for (offset in 0..14) {
            val date = LocalDate.now().plusDays(offset.toLong())
            val shift = ShiftWidgetHelper.getShiftWithOverride(context, team, date)
            val wakeTime = getWakeTime(context, shift) ?: continue  // 휴무면 skip

            val alarmCal = Calendar.getInstance().apply {
                set(Calendar.YEAR, date.year)
                set(Calendar.MONTH, date.monthValue - 1)
                set(Calendar.DAY_OF_MONTH, date.dayOfMonth)
                set(Calendar.HOUR_OF_DAY, wakeTime.first)
                set(Calendar.MINUTE, wakeTime.second)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (alarmCal.timeInMillis > now.timeInMillis) {
                setAlarmAt(context, alarmCal.timeInMillis,
                    "CSPI ${shift} 근무 기상!", shift)
                return
            }
        }
    }

    // 특정 시각(밀리초)에 알람 예약
    private fun setAlarmAt(context: Context, triggerAt: Long, label: String, shift: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.example.cspi.WAKE_UP_ALARM"
            putExtra("ALARM_LABEL", label)
            putExtra("ALARM_SHIFT", shift)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        val pi = PendingIntent.getBroadcast(context, ALARM_REQUEST_CODE, intent, flags)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } catch (e: SecurityException) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }

    private fun cancelAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.example.cspi.WAKE_UP_ALARM"
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        val pi = PendingIntent.getBroadcast(context, ALARM_REQUEST_CODE, intent, flags)
        alarmManager.cancel(pi)
    }

    // 스누즈: 지금부터 minutes분 뒤에 같은 알람 다시 울림
    fun snoozeAlarm(context: Context, minutes: Int, shift: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.example.cspi.WAKE_UP_ALARM"
            putExtra("ALARM_LABEL", "CSPI ${shift} 근무 기상! (다시 울림)")
            putExtra("ALARM_SHIFT", shift)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        val pi = PendingIntent.getBroadcast(context, ALARM_REQUEST_CODE, intent, flags)
        val triggerAt = System.currentTimeMillis() + minutes * 60_000L
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } catch (e: SecurityException) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }
}
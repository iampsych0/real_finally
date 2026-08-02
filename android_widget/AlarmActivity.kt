package com.example.cspi

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

import java.util.Calendar

class AlarmActivity : Activity() {

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var shift: String = "D"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 잠금화면 위에 표시 + 화면 켜기
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            km.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val label = intent.getStringExtra("ALARM_LABEL") ?: "근무 기상 알람!"
        shift = intent.getStringExtra("ALARM_SHIFT") ?: "D"

        buildUi(label)
        startAlarm()
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    private fun buildUi(label: String) {
        val bg = 0xFF232B3E.toInt()  // 스크린샷의 진한 남색
        val cream = 0xFFF5EFE6.toInt()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(bg)
            setPadding(dp(24), dp(48), dp(24), dp(40))
        }

        val cal = Calendar.getInstance()
        val hour24 = cal.get(Calendar.HOUR_OF_DAY)
        val minute = cal.get(Calendar.MINUTE)
        val isAm = hour24 < 12
        var hour12 = hour24 % 12
        if (hour12 == 0) hour12 = 12

        // 상단 여백
        val topSpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1f)
        }
        root.addView(topSpacer)

        // 오전/오후
        val amPm = TextView(this).apply {
            text = if (isAm) "오전" else "오후"
            setTextColor(cream)
            textSize = 40f
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        root.addView(amPm)

        // 큰 시계
        val clock = TextView(this).apply {
            text = String.format("%02d:%02d", hour12, minute)
            setTextColor(cream)
            textSize = 88f
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        root.addView(clock)

        // 날짜
        val dayNames = arrayOf("일", "월", "화", "수", "목", "금", "토")
        val dow = dayNames[cal.get(Calendar.DAY_OF_WEEK) - 1]
        val dateText = TextView(this).apply {
            text = String.format("%d.%02d.%02d(%s)",
                cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1,
                cal.get(Calendar.DAY_OF_MONTH), dow)
            setTextColor(cream)
            textSize = 22f
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, dp(28))
        }
        root.addView(dateText)

        // 캐릭터 이미지
        try {
            val img = ImageView(this).apply {
                val resId = resources.getIdentifier("alarm_character", "drawable", packageName)
                if (resId != 0) setImageResource(resId)
                layoutParams = LinearLayout.LayoutParams(dp(150), dp(150))
            }
            root.addView(img)
        } catch (e: Exception) { }

        // 근무 배지 (색깔 원 + 글자)
        val badge = TextView(this).apply {
            text = shift
            setTextColor(if (shift == "D") Color.BLACK else Color.WHITE)
            textSize = 24f
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
            val size = dp(56)
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                topMargin = dp(12)
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(shiftColor(shift))
            }
        }
        root.addView(badge)

        // 하단 여백
        val bottomSpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1f)
        }
        root.addView(bottomSpacer)

        // 스누즈 버튼 행 (5분 / 10분)
        val snoozeRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(16) }
        }
        snoozeRow.addView(makeSnoozeButton("5분", 5))
        val gap = View(this).apply { layoutParams = LinearLayout.LayoutParams(dp(16), 1) }
        snoozeRow.addView(gap)
        snoozeRow.addView(makeSnoozeButton("10분", 10))
        root.addView(snoozeRow)

        // 알람 종료 버튼
        val dismissBtn = Button(this).apply {
            text = "알람 종료"
            setTextColor(0xFF232B3E.toInt())
            textSize = 20f
            setTypeface(null, Typeface.BOLD)
            isAllCaps = false
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(40).toFloat()
                setColor(Color.WHITE)
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(64)
            )
            setOnClickListener {
                stopAlarm()
                finish()
            }
        }
        root.addView(dismissBtn)

        setContentView(root)
    }

    private fun makeSnoozeButton(text: String, minutes: Int): Button {
        return Button(this).apply {
            this.text = "⏰ $text"
            setTextColor(0xFF232B3E.toInt())
            textSize = 16f
            setTypeface(null, Typeface.BOLD)
            isAllCaps = false
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(40).toFloat()
                setColor(0xFFD8D8D8.toInt())
            }
            layoutParams = LinearLayout.LayoutParams(dp(130), dp(56))
            setOnClickListener {
                snooze(minutes)
            }
        }
    }

    private fun shiftColor(s: String): Int = when (s) {
        "D"  -> 0xFFF5C147.toInt()  // 노랑
        "S"  -> 0xFF888780.toInt()  // 회색
        "G"  -> 0xFF2B2B2B.toInt()  // 검정
        "DS" -> 0xFF378ADD.toInt()  // 파랑
        else -> 0xFF888780.toInt()
    }

    private fun snooze(minutes: Int) {
        stopAlarm()
        // minutes 뒤에 같은 알람 다시 예약
        AlarmScheduler.snoozeAlarm(applicationContext, minutes, shift)
        finish()
    }

    private fun startAlarm() {
        // 소리/진동은 AlarmService(포그라운드 서비스)가 재생하므로
        // 화면에서는 아무것도 하지 않음 (중복 방지)
        // 혹시 서비스가 안 떠 있으면(직접 실행 등) 대비해 시작
        val label = intent.getStringExtra("ALARM_LABEL") ?: "근무 기상 알람!"
        if (!AlarmService.isRunning) {
            AlarmService.start(applicationContext, label, shift)
        }
    }

    private fun stopAlarm() {
        // 서비스 정지 → 소리/진동 멈춤
        AlarmService.stop(applicationContext)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        nm.cancel(7001)
        nm.cancel(AlarmService.NOTI_ID)
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAlarm()
    }
}

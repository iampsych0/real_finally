package com.example.cspi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import org.json.JSONObject
import java.time.LocalDate
import java.time.temporal.ChronoUnit

// 소형 1칸 (오늘만)
class ShiftWidgetSmall1 : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) ShiftWidgetHelper.updateSmall1(context, mgr, id)
    }
}
// 주간형 (7일)
class ShiftWidgetWeekly : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) ShiftWidgetHelper.updateWeekly(context, mgr, id)
    }
}
// 전체조 (4조 4일)
class ShiftWidgetAllTeam : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) ShiftWidgetHelper.updateAllTeam(context, mgr, id)
    }
}
// 달력형
class ShiftWidgetCalendar : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) ShiftWidgetHelper.updateCalendar(context, mgr, id)
    }
}

object ShiftWidgetHelper {
    private val REF = LocalDate.of(2026, 6, 1)
    private val A_CYCLE = arrayOf("S","OFF","D","D","D","OFF","OFF","D","D","OFF","G","G","G","G","OFF","S","S","S","S","OFF","OFF","G","G","G","OFF","OFF","DS","DS")
    private val B_CYCLE = arrayOf("G","G","G","OFF","OFF","DS","DS","S","OFF","D","D","D","OFF","OFF","D","D","OFF","G","G","G","G","OFF","S","S","S","S","OFF","OFF")
    private val C_CYCLE = arrayOf("OFF","S","S","S","S","OFF","OFF","G","G","G","OFF","OFF","DS","DS","S","OFF","D","D","D","OFF","OFF","D","D","OFF","G","G","G","G")
    private val D_CYCLE = arrayOf("D","D","OFF","G","G","G","G","OFF","S","S","S","S","OFF","OFF","G","G","G","OFF","OFF","DS","DS","S","OFF","D","D","D","OFF","OFF")

    private fun cycle(team: String) = when(team) { "A"->A_CYCLE; "B"->B_CYCLE; "C"->C_CYCLE; else->D_CYCLE }

    fun getShift(team: String, date: LocalDate): String {
        val diff = ChronoUnit.DAYS.between(REF, date).toInt()
        return cycle(team)[((diff % 28) + 28) % 28]
    }

    // override(수동 변경)를 우선 반영하는 버전 — 위젯/알람이 사용
    fun getShiftWithOverride(context: Context, team: String, date: LocalDate): String {
        val ov = getOverride(context, team, date)
        if (ov != null) return ov
        return getShift(team, date)
    }

    private fun getOverride(context: Context, team: String, date: LocalDate): String? {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.shift_overrides_v2", null) ?: return null
            val key = "%s_%04d-%02d-%02d".format(team, date.year, date.monthValue, date.dayOfMonth)
            val json = org.json.JSONObject(raw)
            if (json.has(key)) json.getString(key) else null
        } catch (e: Exception) { null }
    }

    fun shiftName(s: String) = when(s) { "D"->"주간근무";"G"->"야간근무";"S"->"저녁근무";"DS"->"주간+저녁";else->"휴무" }
    fun shiftBg(s: String) = when(s) { "D"->0xFFFAC775.toInt();"G"->0xFF2C2C2A.toInt();"S"->0xFF888780.toInt();"DS"->0xFF378ADD.toInt();else->0xFFEEEEEE.toInt() }
    fun shiftFg(s: String) = when(s) { "D"->0xFF412402.toInt();"G"->0xFFD3D1C7.toInt();"S"->0xFFF1EFE8.toInt();"DS"->0xFFE6F1FB.toInt();else->0xFFE24B4A.toInt() }

    private fun getTeam(context: Context) =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.my_team", "B") ?: "B"

    // 공휴일 여부 확인 (Flutter HolidayService가 저장한 캐시 읽기)
    private fun isHoliday(context: Context, date: LocalDate): Boolean {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val json = prefs.getString("flutter.holidays_${date.year}", null) ?: return false
            val obj = JSONObject(json)
            val key = "${date.year}-${date.monthValue.toString().padStart(2,'0')}-${date.dayOfMonth.toString().padStart(2,'0')}"
            obj.has(key)
        } catch (e: Exception) {
            false
        }
    }

    private fun launchPi(context: Context) = PendingIntent.getActivity(
        context, 0, context.packageManager.getLaunchIntentForPackage(context.packageName),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private val DOW = arrayOf("월","화","수","목","금","토","일")

    fun shiftCircleDrawable(s: String) = when(s) {
        "D"  -> R.drawable.badge_circle_day
        "G"  -> R.drawable.badge_circle_night
        "S"  -> R.drawable.badge_circle_evening
        "DS" -> R.drawable.badge_circle_ds
        else -> 0
    }

    fun shiftPillDrawable(s: String) = when(s) {
        "D"  -> R.drawable.pill_day
        "G"  -> R.drawable.pill_night
        "S"  -> R.drawable.pill_evening
        "DS" -> R.drawable.pill_ds
        else -> 0
    }

    // 뱃지 뷰에 알약(근무) 또는 투명+빨간글씨(휴무) 적용
    fun applyPillBadge(v: RemoteViews, viewId: Int, shift: String) {
        if (shift == "OFF") {
            v.setInt(viewId, "setBackgroundColor", 0x00000000)
            v.setInt(viewId, "setTextColor", 0xFFE24B4A.toInt())
        } else {
            v.setInt(viewId, "setBackgroundResource", shiftPillDrawable(shift))
            v.setInt(viewId, "setTextColor", shiftFg(shift))
        }
    }

    // 뱃지 뷰에 동그라미(근무) 또는 투명+빨간글씨(휴무) 적용
    fun applyCircleBadge(v: RemoteViews, viewId: Int, shift: String) {
        if (shift == "OFF") {
            v.setInt(viewId, "setBackgroundColor", 0x00000000)
            v.setInt(viewId, "setTextColor", 0xFFE24B4A.toInt())
        } else {
            v.setInt(viewId, "setBackgroundResource", shiftCircleDrawable(shift))
            v.setInt(viewId, "setTextColor", shiftFg(shift))
        }
    }

    // ── 소형 1칸 (오늘만) ──
    fun updateSmall1(context: Context, mgr: AppWidgetManager, id: Int) {
        val team = getTeam(context)
        val today = LocalDate.now()
        val s = getShiftWithOverride(context, team, today)
        val dow = DOW[today.dayOfWeek.value - 1]
        val v = RemoteViews(context.packageName, R.layout.widget_layout_small1)
        v.setTextViewText(R.id.small1_date, "${today.dayOfMonth}\n${dow}")
        v.setTextViewText(R.id.small1_shift, if(s=="OFF") "휴" else s)
        applyCircleBadge(v, R.id.small1_shift, s)
        v.setOnClickPendingIntent(R.id.widget_small1_root, launchPi(context))
        mgr.updateAppWidget(id, v)
    }

    // ── 주간형 ──
    fun updateWeekly(context: Context, mgr: AppWidgetManager, id: Int) {
        val team = getTeam(context)
        val today = LocalDate.now()
        val v = RemoteViews(context.packageName, R.layout.widget_layout_weekly)
        val dateIds = intArrayOf(R.id.week_date_0,R.id.week_date_1,R.id.week_date_2,R.id.week_date_3,R.id.week_date_4,R.id.week_date_5,R.id.week_date_6)
        val dowIds  = intArrayOf(R.id.week_dow_0,R.id.week_dow_1,R.id.week_dow_2,R.id.week_dow_3,R.id.week_dow_4,R.id.week_dow_5,R.id.week_dow_6)
        val shiftIds= intArrayOf(R.id.week_shift_0,R.id.week_shift_1,R.id.week_shift_2,R.id.week_shift_3,R.id.week_shift_4,R.id.week_shift_5,R.id.week_shift_6)
        for (i in 0..6) {
            val d = today.plusDays(i.toLong())
            val s = getShiftWithOverride(context, team, d)
            val isSun = d.dayOfWeek.value==7; val isSat = d.dayOfWeek.value==6
            v.setTextViewText(dateIds[i], "${d.dayOfMonth}")
            v.setInt(dateIds[i], "setTextColor", if(i==0) 0xFF378ADD.toInt() else if(isSun) 0xFFE24B4A.toInt() else if(isSat) 0xFF378ADD.toInt() else 0xFF555555.toInt())
            v.setTextViewText(dowIds[i], DOW[d.dayOfWeek.value-1])
            v.setInt(dowIds[i], "setTextColor", if(isSun) 0xFFE24B4A.toInt() else if(isSat) 0xFF378ADD.toInt() else 0xFF888780.toInt())
            v.setTextViewText(shiftIds[i], if(s=="OFF") "휴" else s)
            applyCircleBadge(v, shiftIds[i], s)
        }
        v.setOnClickPendingIntent(R.id.widget_weekly_root, launchPi(context))
        mgr.updateAppWidget(id, v)
    }

    // ── 전체조 (7일, 동그라미) ──
    fun updateAllTeam(context: Context, mgr: AppWidgetManager, id: Int) {
        val myTeam = getTeam(context)
        val today = LocalDate.now()
        val v = RemoteViews(context.packageName, R.layout.widget_layout_allteam)
        val dateIds = intArrayOf(R.id.at_date_0,R.id.at_date_1,R.id.at_date_2,R.id.at_date_3,R.id.at_date_4,R.id.at_date_5,R.id.at_date_6)
        val teamCellIds = mapOf(
            "A" to intArrayOf(R.id.at_a_0,R.id.at_a_1,R.id.at_a_2,R.id.at_a_3,R.id.at_a_4,R.id.at_a_5,R.id.at_a_6),
            "B" to intArrayOf(R.id.at_b_0,R.id.at_b_1,R.id.at_b_2,R.id.at_b_3,R.id.at_b_4,R.id.at_b_5,R.id.at_b_6),
            "C" to intArrayOf(R.id.at_c_0,R.id.at_c_1,R.id.at_c_2,R.id.at_c_3,R.id.at_c_4,R.id.at_c_5,R.id.at_c_6),
            "D" to intArrayOf(R.id.at_d_0,R.id.at_d_1,R.id.at_d_2,R.id.at_d_3,R.id.at_d_4,R.id.at_d_5,R.id.at_d_6)
        )
        for (i in 0..6) {
            val d = today.plusDays(i.toLong())
            val isSun = d.dayOfWeek.value==7; val isSat = d.dayOfWeek.value==6
            v.setTextViewText(dateIds[i], "${d.dayOfMonth}\n${DOW[d.dayOfWeek.value-1]}")
            v.setInt(dateIds[i], "setTextColor", if(i==0) 0xFF378ADD.toInt() else if(isSun) 0xFFE24B4A.toInt() else if(isSat) 0xFF378ADD.toInt() else 0xFF555555.toInt())
            for (team in listOf("A","B","C","D")) {
                val s = getShiftWithOverride(context, team, d)
                val cellId = teamCellIds[team]!![i]
                v.setTextViewText(cellId, if(s=="OFF") "휴" else s)
                applyPillBadge(v, cellId, s)
            }
        }
        v.setOnClickPendingIntent(R.id.widget_allteam_root, launchPi(context))
        mgr.updateAppWidget(id, v)
    }

    // ── 달력형 (날짜 + 동그라미 근무 분리) ──
    fun updateCalendar(context: Context, mgr: AppWidgetManager, id: Int) {
        val team = getTeam(context)
        val today = LocalDate.now()
        val v = RemoteViews(context.packageName, R.layout.widget_layout_calendar)
        v.setTextViewText(R.id.cal_month, "${today.year}. ${today.monthValue.toString().padStart(2,'0')}")
        val firstDay = LocalDate.of(today.year, today.month, 1)
        val startCol = firstDay.dayOfWeek.value % 7
        val daysInMonth = today.month.length(firstDay.isLeapYear)
        val weeksNeeded = ((startCol + daysInMonth) + 6) / 7  // 실제 필요한 주 수 (5 또는 6)

        val weekRowIds = intArrayOf(R.id.cal_week_0,R.id.cal_week_1,R.id.cal_week_2,R.id.cal_week_3,R.id.cal_week_4,R.id.cal_week_5)
        for (w in 0..5) {
            v.setViewVisibility(weekRowIds[w], if (w < weeksNeeded) android.view.View.VISIBLE else android.view.View.GONE)
        }

        val dateCellIds = arrayOf(
            intArrayOf(R.id.cal_date_00,R.id.cal_date_01,R.id.cal_date_02,R.id.cal_date_03,R.id.cal_date_04,R.id.cal_date_05,R.id.cal_date_06),
            intArrayOf(R.id.cal_date_10,R.id.cal_date_11,R.id.cal_date_12,R.id.cal_date_13,R.id.cal_date_14,R.id.cal_date_15,R.id.cal_date_16),
            intArrayOf(R.id.cal_date_20,R.id.cal_date_21,R.id.cal_date_22,R.id.cal_date_23,R.id.cal_date_24,R.id.cal_date_25,R.id.cal_date_26),
            intArrayOf(R.id.cal_date_30,R.id.cal_date_31,R.id.cal_date_32,R.id.cal_date_33,R.id.cal_date_34,R.id.cal_date_35,R.id.cal_date_36),
            intArrayOf(R.id.cal_date_40,R.id.cal_date_41,R.id.cal_date_42,R.id.cal_date_43,R.id.cal_date_44,R.id.cal_date_45,R.id.cal_date_46),
            intArrayOf(R.id.cal_date_50,R.id.cal_date_51,R.id.cal_date_52,R.id.cal_date_53,R.id.cal_date_54,R.id.cal_date_55,R.id.cal_date_56)
        )
        val shiftCellIds = arrayOf(
            intArrayOf(R.id.cal_shift_00,R.id.cal_shift_01,R.id.cal_shift_02,R.id.cal_shift_03,R.id.cal_shift_04,R.id.cal_shift_05,R.id.cal_shift_06),
            intArrayOf(R.id.cal_shift_10,R.id.cal_shift_11,R.id.cal_shift_12,R.id.cal_shift_13,R.id.cal_shift_14,R.id.cal_shift_15,R.id.cal_shift_16),
            intArrayOf(R.id.cal_shift_20,R.id.cal_shift_21,R.id.cal_shift_22,R.id.cal_shift_23,R.id.cal_shift_24,R.id.cal_shift_25,R.id.cal_shift_26),
            intArrayOf(R.id.cal_shift_30,R.id.cal_shift_31,R.id.cal_shift_32,R.id.cal_shift_33,R.id.cal_shift_34,R.id.cal_shift_35,R.id.cal_shift_36),
            intArrayOf(R.id.cal_shift_40,R.id.cal_shift_41,R.id.cal_shift_42,R.id.cal_shift_43,R.id.cal_shift_44,R.id.cal_shift_45,R.id.cal_shift_46),
            intArrayOf(R.id.cal_shift_50,R.id.cal_shift_51,R.id.cal_shift_52,R.id.cal_shift_53,R.id.cal_shift_54,R.id.cal_shift_55,R.id.cal_shift_56)
        )

        // 전체 칸 초기화
        for (row in dateCellIds) for (cid in row) v.setTextViewText(cid, "")
        for (row in shiftCellIds) for (cid in row) {
            v.setTextViewText(cid, "")
            v.setInt(cid, "setBackgroundColor", 0x00000000)
        }

        var day = 1
        for (pos in 0 until 42) {
            val row = pos/7; val col = pos%7
            if (pos < startCol || day > daysInMonth) continue
            val d = LocalDate.of(today.year, today.month, day)
            val shift = getShiftWithOverride(context, team, d)
            val isToday = day == today.dayOfMonth
            val isSun = col==0; val isSat = col==6

            val dateCellId = dateCellIds[row][col]
            val shiftCellId = shiftCellIds[row][col]
            val holiday = isHoliday(context, d)

            // 날짜 숫자 (평범하게 표시, 오늘은 옅은 파란 배경, 공휴일은 빨간 글씨)
            v.setTextViewText(dateCellId, "$day")
            val dateColor = when {
                isToday -> 0xFF185FA5.toInt()
                holiday || isSun -> 0xFFE24B4A.toInt()
                isSat -> 0xFF378ADD.toInt()
                else -> 0xFF1A1A1A.toInt()
            }
            v.setInt(dateCellId, "setTextColor", dateColor)
            if (isToday) {
                v.setInt(dateCellId, "setBackgroundResource", R.drawable.today_border)
            } else {
                v.setInt(dateCellId, "setBackgroundColor", 0x00000000)
            }

            // 근무 알파벳 (동그라미, 휴무는 빈칸)
            if (shift == "OFF") {
                v.setTextViewText(shiftCellId, "휴")
                v.setInt(shiftCellId, "setBackgroundColor", 0x00000000)
                v.setInt(shiftCellId, "setTextColor", 0xFFE24B4A.toInt())
            } else {
                v.setTextViewText(shiftCellId, shift)
                v.setInt(shiftCellId, "setBackgroundResource", shiftCircleDrawable(shift))
                v.setInt(shiftCellId, "setTextColor", shiftFg(shift))
            }
            day++
        }
        v.setOnClickPendingIntent(R.id.widget_calendar_root, launchPi(context))
        mgr.updateAppWidget(id, v)
    }
}

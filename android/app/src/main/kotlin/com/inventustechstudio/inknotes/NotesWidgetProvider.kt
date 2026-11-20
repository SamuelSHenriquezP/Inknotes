package com.inventustechstudio.inknotes

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray

class NotesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        refresh(context)
    }

    companion object {
        fun refresh(context: Context) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isProtected = prefs.getBoolean("flutter.sec_pin_enabled", false)
            var title = if (isProtected) "Notas protegidas" else "Tu nota fijada"
            var preview = if (isProtected) "Abre inkNotes para desbloquear" else "Fija una nota para verla aquí"
            var action = "new"
            if (!isProtected) {
                try {
                    val notes = JSONArray(prefs.getString("flutter.ink_notes_notes", "[]"))
                    for (i in 0 until notes.length()) {
                        val note = notes.getJSONObject(i)
                        if (note.isNull("deletedAt") && note.optBoolean("isPinned")) {
                            title = note.optString("title").ifBlank { "Sin título" }
                            preview = note.optString("content").take(280)
                            action = note.getString("id")
                            break
                        }
                    }
                } catch (_: Exception) { }
            }
            val views = RemoteViews(context.packageName, R.layout.notes_widget)
            views.setTextViewText(R.id.note_title, title)
            views.setTextViewText(R.id.note_preview, preview)
            fun pending(value: String, code: Int): PendingIntent {
                val intent = Intent(context, MainActivity::class.java)
                    .putExtra("noteAction", value)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                return PendingIntent.getActivity(context, code, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            }
            views.setOnClickPendingIntent(R.id.note_body, pending(action, 101))
            views.setOnClickPendingIntent(R.id.quick_note, pending("new", 102))
            AppWidgetManager.getInstance(context).updateAppWidget(
                ComponentName(context, NotesWidgetProvider::class.java), views)
        }
    }
}

package fyi.imdaniel.smalltools.widget

import android.content.Context
import android.content.SharedPreferences

object WidgetPrefs {

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)

    fun saveTool(context: Context, appWidgetId: Int, toolId: String, toolTitle: String) {
        prefs(context).edit()
            .putString("tool_id_$appWidgetId", toolId)
            .putString("tool_title_$appWidgetId", toolTitle)
            .apply()
    }

    fun getToolId(context: Context, appWidgetId: Int): String? =
        prefs(context).getString("tool_id_$appWidgetId", null)

    fun getToolTitle(context: Context, appWidgetId: Int): String? =
        prefs(context).getString("tool_title_$appWidgetId", null)

    fun clear(context: Context, appWidgetId: Int) {
        prefs(context).edit()
            .remove("tool_id_$appWidgetId")
            .remove("tool_title_$appWidgetId")
            .apply()
    }
}

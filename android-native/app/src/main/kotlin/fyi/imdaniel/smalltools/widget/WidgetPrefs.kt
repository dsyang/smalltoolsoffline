package fyi.imdaniel.smalltools.widget

import android.content.Context
import android.content.SharedPreferences

data class ToolData(val toolId: String, val toolTitle: String)

object WidgetPrefs {

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)

    fun saveTool(context: Context, appWidgetId: Int, toolId: String, toolTitle: String) {
        prefs(context).edit()
            .putString("tool_id_$appWidgetId", toolId)
            .putString("tool_title_$appWidgetId", toolTitle)
            .apply()
    }

    /** Returns both id and title in a single SharedPreferences open, or null if not configured. */
    fun getToolData(context: Context, appWidgetId: Int): ToolData? {
        val p = prefs(context)
        val id = p.getString("tool_id_$appWidgetId", null) ?: return null
        val title = p.getString("tool_title_$appWidgetId", null) ?: return null
        return ToolData(id, title)
    }

    fun clear(context: Context, appWidgetId: Int) {
        prefs(context).edit()
            .remove("tool_id_$appWidgetId")
            .remove("tool_title_$appWidgetId")
            .apply()
    }
}

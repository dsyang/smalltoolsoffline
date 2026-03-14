package fyi.imdaniel.smalltools.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import fyi.imdaniel.smalltools.MainActivity
import fyi.imdaniel.smalltools.shortcuts.ShortcutsManager

class ToolWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        // Single SharedPreferences open instead of two separate gets
        val toolData = WidgetPrefs.getToolData(context, appWidgetId)

        val launchIntent = toolData?.let { td ->
            Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("smalltools://open/${td.toolId}")
                flags = ShortcutsManager.LAUNCH_FLAGS
            }
        }

        provideContent {
            GlanceTheme {
                ToolWidgetContent(
                    toolTitle = toolData?.toolTitle ?: "Small Tools",
                    onClick = launchIntent?.let { actionStartActivity(it) },
                )
            }
        }
    }
}

@Composable
private fun ToolWidgetContent(
    toolTitle: String,
    onClick: androidx.glance.action.Action?,
) {
    val modifier = GlanceModifier
        .fillMaxSize()
        .background(GlanceTheme.colors.surface)
        .padding(12.dp)
        .then(if (onClick != null) GlanceModifier.clickable(onClick) else GlanceModifier)

    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "Small Tools",
                style = TextStyle(fontSize = 11.sp, color = GlanceTheme.colors.onSurfaceVariant),
            )
            Spacer(modifier = GlanceModifier.height(4.dp))
            Text(
                text = toolTitle,
                style = TextStyle(
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                    color = GlanceTheme.colors.onSurface,
                ),
            )
        }
    }
}

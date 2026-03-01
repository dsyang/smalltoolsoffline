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

class ToolWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        val toolId = WidgetPrefs.getToolId(context, appWidgetId)
        val toolTitle = WidgetPrefs.getToolTitle(context, appWidgetId) ?: "Small Tools"

        val launchIntent = toolId?.let { slug ->
            Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("smalltools://open/$slug")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        }

        provideContent {
            GlanceTheme {
                ToolWidgetContent(
                    toolTitle = toolTitle,
                    hasTarget = launchIntent != null,
                    onClick = launchIntent?.let { actionStartActivity(it) },
                )
            }
        }
    }
}

@Composable
private fun ToolWidgetContent(
    toolTitle: String,
    hasTarget: Boolean,
    onClick: androidx.glance.action.Action?,
) {
    val modifier = GlanceModifier
        .fillMaxSize()
        .background(GlanceTheme.colors.surface)
        .padding(12.dp)
        .then(if (onClick != null) GlanceModifier.clickable(onClick) else GlanceModifier)

    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "Small Tools",
                style = TextStyle(
                    fontSize = 11.sp,
                    color = GlanceTheme.colors.onSurfaceVariant,
                ),
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

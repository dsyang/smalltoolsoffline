package fyi.imdaniel.smalltools.widget

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.glance.appwidget.GlanceAppWidgetManager
import fyi.imdaniel.smalltools.model.Manifest
import fyi.imdaniel.smalltools.model.Tool
import fyi.imdaniel.smalltools.ui.theme.SmallToolsTheme
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import java.io.File

class ToolWidgetConfigActivity : ComponentActivity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    @OptIn(ExperimentalMaterial3Api::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        // Default to CANCELED so back press dismisses the widget placement
        setResult(RESULT_CANCELED)

        val tools = loadCachedTools()

        setContent {
            SmallToolsTheme {
                val scope = rememberCoroutineScope()

                Scaffold(
                    topBar = { TopAppBar(title = { Text("Choose a Tool") }) },
                ) { padding ->
                    LazyColumn(modifier = Modifier.padding(padding)) {
                        items(tools) { tool ->
                            ListItem(
                                headlineContent = { Text(tool.title) },
                                supportingContent = { Text(tool.description, maxLines = 1) },
                                modifier = Modifier.clickable {
                                    scope.launch {
                                        WidgetPrefs.saveTool(
                                            context = applicationContext,
                                            appWidgetId = appWidgetId,
                                            toolId = tool.id,
                                            toolTitle = tool.title,
                                        )
                                        GlanceAppWidgetManager(applicationContext)
                                            .getGlanceIds(ToolWidget::class.java)
                                            .forEach { glanceId ->
                                                ToolWidget().update(applicationContext, glanceId)
                                            }
                                        setResult(
                                            RESULT_OK,
                                            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
                                        )
                                        finish()
                                    }
                                },
                            )
                            HorizontalDivider()
                        }
                    }
                }
            }
        }
    }

    private fun loadCachedTools(): List<Tool> {
        val manifestFile = File(filesDir, "manifest.json")
        if (!manifestFile.exists()) return emptyList()
        return runCatching {
            val json = Json { ignoreUnknownKeys = true }
            json.decodeFromString<Manifest>(manifestFile.readText()).tools
        }.getOrDefault(emptyList())
    }
}

package fyi.imdaniel.smalltools.ui.screens

import android.webkit.WebSettings
import android.webkit.WebView
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import fyi.imdaniel.smalltools.model.Tool
import fyi.imdaniel.smalltools.viewmodel.ToolViewModel

@Composable
fun ToolViewerScreen(
    tool: Tool,
    viewModel: ToolViewModel,
    onBack: () -> Unit,
) {
    val downloadedIds by viewModel.downloadedIds.collectAsStateWithLifecycle()

    val hasLocalFile = tool.id in downloadedIds

    // Trigger download if the file isn't local yet. download() is idempotent —
    // it guards against concurrent calls internally and swallows errors.
    LaunchedEffect(tool.id) {
        if (!hasLocalFile) viewModel.download(tool)
    }

    Box(modifier = Modifier.fillMaxSize().safeDrawingPadding()) {
        when {
            hasLocalFile -> {
                val fileUrl = remember(tool.id) { "file://${viewModel.localFile(tool).absolutePath}" }
                // Track the last URL we actually loaded so recompositions don't reload the page.
                var loadedUrl by remember { mutableStateOf("") }

                AndroidView(
                    modifier = Modifier.fillMaxSize(),
                    factory = { context ->
                        WebView.setWebContentsDebuggingEnabled(true)
                        WebView(context).apply {
                            settings.apply {
                                javaScriptEnabled = true
                                domStorageEnabled = true
                                allowFileAccess = true
                                @Suppress("DEPRECATION")   // needed for local file:// → file:// resource loads
                                allowFileAccessFromFileURLs = true
                                cacheMode = WebSettings.LOAD_DEFAULT
                            }
                            overScrollMode = WebView.OVER_SCROLL_NEVER
                        }
                    },
                    update = { webView ->
                        if (loadedUrl != fileUrl) {
                            loadedUrl = fileUrl
                            webView.loadUrl(fileUrl)
                        }
                    },
                )
            }
            else -> {
                // Downloading — mirrors iOS ProgressView + tool name text
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    CircularProgressIndicator()
                    Text("Downloading ${tool.title}…")
                }
            }
        }

        FilledIconButton(
            onClick = onBack,
            modifier = Modifier
                .padding(start = 12.dp, top = 8.dp)
                .size(40.dp)
                .align(Alignment.TopStart),
        ) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
        }
    }
}

package fyi.imdaniel.smalltools.ui.screens

import android.webkit.WebSettings
import android.webkit.WebView
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
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
    val downloadingIds by viewModel.downloadingIds.collectAsStateWithLifecycle()

    val hasLocalFile = tool.id in downloadedIds
    val isDownloading = tool.id in downloadingIds
    var errorMessage by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(tool.id) {
        if (!hasLocalFile) {
            try {
                viewModel.download(tool)
            } catch (e: Exception) {
                errorMessage = e.message ?: "Download failed"
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        when {
            hasLocalFile -> {
                val file = viewModel.localFile(tool)
                AndroidView(
                    modifier = Modifier.fillMaxSize(),
                    factory = { context ->
                        WebView(context).apply {
                            settings.apply {
                                javaScriptEnabled = true
                                domStorageEnabled = true
                                allowFileAccess = true
                                @Suppress("DEPRECATION")
                                allowFileAccessFromFileURLs = true
                                cacheMode = WebSettings.LOAD_DEFAULT
                            }
                            overScrollMode = WebView.OVER_SCROLL_NEVER
                        }
                    },
                    update = { webView ->
                        webView.loadUrl("file://${file.absolutePath}")
                    },
                )
            }
            errorMessage != null -> {
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text("Download Failed", style = MaterialTheme.typography.headlineSmall)
                    Text(
                        errorMessage!!,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            else -> {
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
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
            )
        }
    }
}

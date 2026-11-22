package fyi.imdaniel.smalltools.ui.screens

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
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
import androidx.compose.runtime.DisposableEffect
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
import java.io.File

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

    // <input type="file"> support: the WebView hands us a callback, we launch a
    // chooser (gallery/files + camera), and deliver the picked URI back to the page.
    var pendingFileCallback by remember { mutableStateOf<ValueCallback<Array<Uri>>?>(null) }
    var pendingCameraFile by remember { mutableStateOf<File?>(null) }
    var pendingCameraUri by remember { mutableStateOf<Uri?>(null) }

    val fileChooserLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val cameraFile = pendingCameraFile
        val cameraUri = pendingCameraUri
        var uris = WebChromeClient.FileChooserParams.parseResult(result.resultCode, result.data)
        if (uris.isNullOrEmpty() && result.resultCode == Activity.RESULT_OK &&
            cameraFile != null && cameraUri != null && cameraFile.length() > 0
        ) {
            uris = arrayOf(cameraUri)
        }
        // Must always be called (null on cancel) or the input stops responding.
        pendingFileCallback?.onReceiveValue(uris)
        pendingFileCallback = null
        pendingCameraFile = null
        pendingCameraUri = null
    }

    DisposableEffect(Unit) {
        onDispose {
            pendingFileCallback?.onReceiveValue(null)
            pendingFileCallback = null
        }
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
                            webChromeClient = object : WebChromeClient() {
                                override fun onShowFileChooser(
                                    webView: WebView,
                                    filePathCallback: ValueCallback<Array<Uri>>,
                                    fileChooserParams: FileChooserParams,
                                ): Boolean {
                                    pendingFileCallback?.onReceiveValue(null)
                                    pendingFileCallback = filePathCallback

                                    val cameraFile = if (fileChooserParams.acceptsImages()) {
                                        createCameraFile(context)
                                    } else null
                                    pendingCameraFile = cameraFile

                                    val chooser = Intent.createChooser(fileChooserParams.createIntent(), null)
                                    if (cameraFile != null) {
                                        val cameraUri = FileProvider.getUriForFile(
                                            context, "${context.packageName}.fileprovider", cameraFile,
                                        )
                                        val cameraIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                                            .putExtra(MediaStore.EXTRA_OUTPUT, cameraUri)
                                            .addFlags(
                                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                                            )
                                        chooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf(cameraIntent))
                                        pendingCameraUri = cameraUri
                                    }

                                    return try {
                                        fileChooserLauncher.launch(chooser)
                                        true
                                    } catch (e: ActivityNotFoundException) {
                                        pendingFileCallback = null
                                        pendingCameraFile = null
                                        pendingCameraUri = null
                                        false
                                    }
                                }
                            }
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

private fun WebChromeClient.FileChooserParams.acceptsImages(): Boolean {
    val types = acceptTypes.filter { it.isNotBlank() }
    return types.isEmpty() || types.any { it.startsWith("image/") || it == "*/*" }
}

/** Creates an empty temp file in the FileProvider-shared cache dir for a camera capture. */
private fun createCameraFile(context: Context): File? = try {
    val dir = File(context.cacheDir, "camera").apply { mkdirs() }
    // Clear out stale captures so the cache doesn't grow unbounded.
    val cutoff = System.currentTimeMillis() - 24 * 60 * 60 * 1000L
    dir.listFiles()?.filter { it.lastModified() < cutoff }?.forEach { it.delete() }
    File.createTempFile("capture_", ".jpg", dir)
} catch (e: Exception) {
    null
}

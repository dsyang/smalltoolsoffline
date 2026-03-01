package fyi.imdaniel.smalltools.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import fyi.imdaniel.smalltools.model.AppJson
import fyi.imdaniel.smalltools.model.Manifest
import fyi.imdaniel.smalltools.model.Tool
import fyi.imdaniel.smalltools.model.loadManifest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.net.URL
import java.security.MessageDigest

class ToolViewModel(app: Application) : AndroidViewModel(app) {

    private val context = app.applicationContext

    private val toolsDir = File(context.filesDir, "tools").also { it.mkdirs() }
    private val manifestFile = File(context.filesDir, "manifest.json")
    private val manifestUrl = "https://code.imdaniel.fyi/assets.json"

    private val _tools = MutableStateFlow<List<Tool>>(emptyList())
    val tools: StateFlow<List<Tool>> = _tools.asStateFlow()

    private val _downloadedIds = MutableStateFlow<Set<String>>(emptySet())
    val downloadedIds: StateFlow<Set<String>> = _downloadedIds.asStateFlow()

    private val _outdatedIds = MutableStateFlow<Set<String>>(emptySet())
    val outdatedIds: StateFlow<Set<String>> = _outdatedIds.asStateFlow()

    private val _downloadingIds = MutableStateFlow<Set<String>>(emptySet())
    val downloadingIds: StateFlow<Set<String>> = _downloadingIds.asStateFlow()

    private val _isFetchingManifest = MutableStateFlow(false)
    val isFetchingManifest: StateFlow<Boolean> = _isFetchingManifest.asStateFlow()

    private val _isSyncingAll = MutableStateFlow(false)
    val isSyncingAll: StateFlow<Boolean> = _isSyncingAll.asStateFlow()

    init {
        // Load the cached manifest then scan downloads sequentially so the UI
        // never shows a tool list without knowing which files are already present.
        viewModelScope.launch {
            val cached = withContext(Dispatchers.IO) { manifestFile.loadManifest() }
            if (cached != null) {
                _tools.value = cached
                scanDownloaded(cached)
            }
        }
    }

    // MARK: - Public API

    fun fetchManifest() {
        if (_isFetchingManifest.value) return
        viewModelScope.launch { doFetchManifest() }
    }

    fun download(tool: Tool) {
        if (tool.id in _downloadingIds.value) return
        viewModelScope.launch { doDownload(tool) }
    }

    fun syncAll() {
        viewModelScope.launch {
            _isSyncingAll.value = true
            try {
                doFetchManifest()
                // Parallel downloads, all awaited before clearing isSyncingAll
                _tools.value
                    .filter { needsDownload(it) }
                    .map { async { doDownload(it) } }
                    .awaitAll()
            } finally {
                _isSyncingAll.value = false
            }
        }
    }

    fun deleteLocal(tool: Tool) {
        localFile(tool).delete()
        _downloadedIds.update { it - tool.id }
        _outdatedIds.update { it - tool.id }
    }

    // MARK: - State queries

    fun localFile(tool: Tool): File = File(toolsDir, tool.filename)
    fun hasLocalFile(tool: Tool) = tool.id in _downloadedIds.value
    fun isDownloaded(tool: Tool) = tool.id in _downloadedIds.value && tool.id !in _outdatedIds.value
    fun isOutdated(tool: Tool) = tool.id in _outdatedIds.value
    fun isDownloading(tool: Tool) = tool.id in _downloadingIds.value
    fun needsDownload(tool: Tool) = tool.id !in _downloadedIds.value || tool.id in _outdatedIds.value
    fun downloadedTools(): List<Tool> = _tools.value.filter { isDownloaded(it) }

    // MARK: - Private suspend implementations

    private suspend fun doFetchManifest() {
        _isFetchingManifest.value = true
        try {
            val data = withContext(Dispatchers.IO) { URL(manifestUrl).readBytes() }
            val tools = AppJson.decodeFromString<Manifest>(data.decodeToString()).tools
            withContext(Dispatchers.IO) { manifestFile.writeBytes(data) }
            _tools.value = tools
            scanDownloaded(tools)
        } catch (_: Exception) {
            // Keep cached tools on network failure
        } finally {
            _isFetchingManifest.value = false
        }
    }

    /** Scans the filesystem on IO and updates both sets atomically when done. */
    private suspend fun scanDownloaded(tools: List<Tool>) {
        val (downloaded, outdated) = withContext(Dispatchers.IO) {
            val d = mutableSetOf<String>()
            val o = mutableSetOf<String>()
            for (tool in tools) {
                val file = localFile(tool)
                if (!file.exists()) continue
                d += tool.id
                if (sha256(file.readBytes()) != tool.sha256) o += tool.id
            }
            d to o
        }
        _downloadedIds.value = downloaded
        _outdatedIds.value = outdated
    }

    private suspend fun doDownload(tool: Tool) {
        if (tool.id in _downloadingIds.value) return
        _downloadingIds.update { it + tool.id }
        try {
            val data = withContext(Dispatchers.IO) { URL(tool.downloadURL).readBytes() }
            withContext(Dispatchers.IO) { localFile(tool).writeBytes(data) }
            _downloadedIds.update { it + tool.id }
            _outdatedIds.update { it - tool.id }
        } catch (_: Exception) {
            // Leave state unchanged on failure
        } finally {
            _downloadingIds.update { it - tool.id }
        }
    }

    private fun sha256(data: ByteArray): String =
        MessageDigest.getInstance("SHA-256")
            .digest(data)
            .joinToString("") { "%02x".format(it) }
}

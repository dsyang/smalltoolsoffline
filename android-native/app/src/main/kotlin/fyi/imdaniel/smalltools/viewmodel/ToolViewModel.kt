package fyi.imdaniel.smalltools.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import fyi.imdaniel.smalltools.model.Manifest
import fyi.imdaniel.smalltools.model.Tool
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.File
import java.net.URL
import java.security.MessageDigest

class ToolViewModel(app: Application) : AndroidViewModel(app) {

    private val context = app.applicationContext

    private val toolsDir = File(context.filesDir, "tools").also { it.mkdirs() }
    private val manifestFile = File(context.filesDir, "manifest.json")
    private val manifestUrl = "https://code.imdaniel.fyi/assets.json"
    private val json = Json { ignoreUnknownKeys = true }

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
        loadCachedManifest()
    }

    private fun loadCachedManifest() {
        if (!manifestFile.exists()) return
        runCatching {
            val tools = json.decodeFromString<Manifest>(manifestFile.readText()).tools
            _tools.value = tools
            scanDownloaded(tools)
        }
    }

    fun fetchManifest() {
        if (_isFetchingManifest.value) return
        viewModelScope.launch {
            _isFetchingManifest.value = true
            try {
                val data = withContext(Dispatchers.IO) { URL(manifestUrl).readBytes() }
                val tools = json.decodeFromString<Manifest>(data.decodeToString()).tools
                withContext(Dispatchers.IO) { manifestFile.writeBytes(data) }
                _tools.value = tools
                scanDownloaded(tools)
            } catch (_: Exception) {
                // Keep cached tools on failure — mirrors iOS behavior
            } finally {
                _isFetchingManifest.value = false
            }
        }
    }

    private fun scanDownloaded(tools: List<Tool>) {
        viewModelScope.launch(Dispatchers.IO) {
            val downloaded = mutableSetOf<String>()
            val outdated = mutableSetOf<String>()
            for (tool in tools) {
                val file = localFile(tool)
                if (!file.exists()) continue
                downloaded += tool.id
                if (sha256(file.readBytes()) != tool.sha256) outdated += tool.id
            }
            _downloadedIds.value = downloaded
            _outdatedIds.value = outdated
        }
    }

    fun localFile(tool: Tool): File = File(toolsDir, tool.filename)

    fun hasLocalFile(tool: Tool) = tool.id in _downloadedIds.value
    fun isDownloaded(tool: Tool) = tool.id in _downloadedIds.value && tool.id !in _outdatedIds.value
    fun isOutdated(tool: Tool) = tool.id in _outdatedIds.value
    fun isDownloading(tool: Tool) = tool.id in _downloadingIds.value
    fun needsDownload(tool: Tool) = tool.id !in _downloadedIds.value || tool.id in _outdatedIds.value

    fun deleteLocal(tool: Tool) {
        localFile(tool).delete()
        _downloadedIds.update { it - tool.id }
        _outdatedIds.update { it - tool.id }
    }

    fun download(tool: Tool) {
        if (tool.id in _downloadingIds.value) return
        viewModelScope.launch {
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
    }

    fun syncAll() {
        viewModelScope.launch {
            _isSyncingAll.value = true
            try {
                val data = withContext(Dispatchers.IO) { URL(manifestUrl).readBytes() }
                val tools = json.decodeFromString<Manifest>(data.decodeToString()).tools
                withContext(Dispatchers.IO) { manifestFile.writeBytes(data) }
                _tools.value = tools
                scanDownloaded(tools)
                tools.filter { needsDownload(it) }.forEach { tool -> download(tool) }
            } catch (_: Exception) {
            } finally {
                _isSyncingAll.value = false
            }
        }
    }

    fun downloadedTools(): List<Tool> =
        _tools.value.filter { isDownloaded(it) }

    private fun sha256(data: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest(data).joinToString("") { "%02x".format(it) }
    }
}

package fyi.imdaniel.smalltools.model

import kotlinx.serialization.Serializable

@Serializable
data class Tool(
    val title: String,
    val description: String,
    val path: String,
    val sha256: String,
) {
    val id: String get() = path.substringAfterLast('/').substringBeforeLast('.')
    val filename: String get() = path.substringAfterLast('/')
    val downloadURL: String get() = "https://code.imdaniel.fyi/$path"

    companion object {
        fun find(slug: String, tools: List<Tool>): Tool? = tools.firstOrNull { it.id == slug }
    }
}

@Serializable
data class Manifest(val tools: List<Tool>)

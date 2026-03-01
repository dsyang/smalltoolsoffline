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

}

@Serializable
data class Manifest(val tools: List<Tool>)

package fyi.imdaniel.smalltools.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * An additional file a tool depends on (e.g. an image referenced by its HTML).
 * Stored on the CDN alongside the tool and downloaded with it for offline use.
 */
@Serializable
data class Asset(
    val path: String,
    val sha256: String,
    @SerialName("file_size_bytes") val fileSizeBytes: Long? = null,
) {
    val downloadURL: String get() = "https://code.imdaniel.fyi/$path"
}

@Serializable
data class Tool(
    val title: String,
    val description: String,
    val path: String,
    val sha256: String,
    // Older cached manifests may not include the assets array.
    val assets: List<Asset> = emptyList(),
) {
    val id: String get() = path.substringAfterLast('/').substringBeforeLast('.')
    val filename: String get() = path.substringAfterLast('/')
    val downloadURL: String get() = "https://code.imdaniel.fyi/$path"

}

@Serializable
data class Manifest(val tools: List<Tool>)

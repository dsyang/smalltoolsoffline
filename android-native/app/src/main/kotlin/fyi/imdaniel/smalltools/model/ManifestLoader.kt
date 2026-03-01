package fyi.imdaniel.smalltools.model

import kotlinx.serialization.json.Json
import java.io.File

/** Shared JSON parser — single instance avoids re-creating the config on every parse. */
val AppJson = Json { ignoreUnknownKeys = true }

/** Parse the cached manifest file. Returns null on any error (missing / corrupt). */
fun File.loadManifest(): List<Tool>? = runCatching {
    AppJson.decodeFromString<Manifest>(readText()).tools
}.getOrNull()

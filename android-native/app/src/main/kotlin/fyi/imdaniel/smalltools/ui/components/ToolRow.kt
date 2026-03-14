package fyi.imdaniel.smalltools.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Autorenew       // arrow.triangle.2.circlepath.circle.fill
import androidx.compose.material.icons.filled.CheckCircle    // checkmark.circle.fill
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.outlined.ArrowCircleDown  // arrow.down.circle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import fyi.imdaniel.smalltools.model.Tool
import fyi.imdaniel.smalltools.viewmodel.ToolViewModel

// Matches iOS system orange / green used for the same status icons in the iOS app.
private val IosOrange = Color(0xFFFF9500)
private val IosGreen = Color(0xFF34C759)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ToolRow(
    tool: Tool,
    viewModel: ToolViewModel,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    val downloadedIds by viewModel.downloadedIds.collectAsStateWithLifecycle()
    val outdatedIds by viewModel.outdatedIds.collectAsStateWithLifecycle()
    val downloadingIds by viewModel.downloadingIds.collectAsStateWithLifecycle()

    val isDownloading = tool.id in downloadingIds
    val isOutdated = tool.id in outdatedIds
    val isDownloaded = tool.id in downloadedIds && !isOutdated
    val hasLocalFile = tool.id in downloadedIds

    // rememberUpdatedState keeps a State<T> that is always current, even though
    // the confirmValueChange lambda below is captured once by rememberSwipeToDismissBoxState.
    val currentHasLocalFile = rememberUpdatedState(hasLocalFile)

    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart && currentHasLocalFile.value) {
                onDelete()
            }
            false  // always snap back — the tool stays in the list, only the local file is removed
        },
        positionalThreshold = { it * 0.4f },
    )

    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = {
            if (hasLocalFile) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(end = 20.dp),
                    contentAlignment = Alignment.CenterEnd,
                ) {
                    Icon(
                        Icons.Default.Delete,
                        contentDescription = "Delete",
                        tint = MaterialTheme.colorScheme.error,
                    )
                }
            }
        },
        enableDismissFromStartToEnd = false,
    ) {
        ListItem(
            headlineContent = { Text(tool.title) },
            supportingContent = {
                Text(
                    tool.description,
                    maxLines = 1,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            },
            trailingContent = {
                when {
                    // Mirrors iOS ProgressView()
                    isDownloading -> CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                    )
                    // Mirrors iOS arrow.triangle.2.circlepath.circle.fill (orange)
                    isOutdated -> IconButton(onClick = { viewModel.download(tool) }) {
                        Icon(
                            Icons.Filled.Autorenew,
                            contentDescription = "Update available",
                            tint = IosOrange,
                        )
                    }
                    // Mirrors iOS checkmark.circle.fill (green)
                    isDownloaded -> Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = "Downloaded",
                        tint = IosGreen,
                    )
                    // Mirrors iOS arrow.down.circle (secondary)
                    else -> Icon(
                        Icons.Outlined.ArrowCircleDown,
                        contentDescription = "Not downloaded",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            },
            modifier = Modifier.clickable { onClick() },
        )
    }
    HorizontalDivider()
}

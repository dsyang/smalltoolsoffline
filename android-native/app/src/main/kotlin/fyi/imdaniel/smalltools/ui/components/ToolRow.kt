package fyi.imdaniel.smalltools.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Refresh
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import fyi.imdaniel.smalltools.model.Tool
import fyi.imdaniel.smalltools.viewmodel.ToolViewModel

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

    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart && hasLocalFile) {
                onDelete()
                true
            } else {
                false
            }
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
                    isDownloading -> CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                    )
                    isOutdated -> IconButton(onClick = { viewModel.download(tool) }) {
                        Icon(
                            Icons.Default.Refresh,
                            contentDescription = "Update",
                            tint = Color(0xFFFF9500),
                        )
                    }
                    isDownloaded -> Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = "Downloaded",
                        tint = Color(0xFF34C759),
                    )
                    else -> Icon(
                        Icons.Default.ArrowDownward,
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

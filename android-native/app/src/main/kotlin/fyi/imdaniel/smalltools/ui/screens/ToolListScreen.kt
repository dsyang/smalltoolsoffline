package fyi.imdaniel.smalltools.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import fyi.imdaniel.smalltools.model.Tool
import fyi.imdaniel.smalltools.ui.components.ToolRow
import fyi.imdaniel.smalltools.viewmodel.ToolViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ToolListScreen(
    viewModel: ToolViewModel,
    onToolClick: (Tool) -> Unit,
) {
    val tools by viewModel.tools.collectAsStateWithLifecycle()
    val isFetchingManifest by viewModel.isFetchingManifest.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.fetchManifest()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Small Tools") },
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
        ) {
            when {
                tools.isEmpty() && isFetchingManifest -> {
                    Column(
                        modifier = Modifier.align(Alignment.Center),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        CircularProgressIndicator()
                        Text("Loading tools…")
                    }
                }
                tools.isEmpty() -> {
                    Column(
                        modifier = Modifier.align(Alignment.Center),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text("No Tools", style = MaterialTheme.typography.headlineSmall)
                        Text(
                            "Pull to refresh or tap Sync",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                else -> {
                    PullToRefreshBox(
                        isRefreshing = isFetchingManifest,
                        onRefresh = { viewModel.fetchManifest() },
                    ) {
                        LazyColumn(modifier = Modifier.fillMaxSize()) {
                            items(tools, key = { it.id }) { tool ->
                                ToolRow(
                                    tool = tool,
                                    viewModel = viewModel,
                                    onClick = { onToolClick(tool) },
                                    onDelete = { viewModel.deleteLocal(tool) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

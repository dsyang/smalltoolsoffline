package fyi.imdaniel.smalltools

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.navigation.navDeepLink
import fyi.imdaniel.smalltools.shortcuts.ShortcutsManager
import fyi.imdaniel.smalltools.ui.screens.ToolListScreen
import fyi.imdaniel.smalltools.ui.screens.ToolViewerScreen
import fyi.imdaniel.smalltools.ui.theme.SmallToolsTheme
import fyi.imdaniel.smalltools.viewmodel.ToolViewModel

private object Routes {
    const val LIST = "list"
    const val TOOL = "tool/{slug}"
    fun tool(slug: String) = "tool/$slug"
}

class MainActivity : ComponentActivity() {

    // Backed by mutableStateOf so Compose recomposes when onNewIntent fires.
    private var currentIntent by mutableStateOf<Intent?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        currentIntent = intent
        enableEdgeToEdge()

        setContent {
            SmallToolsTheme {
                val navController = rememberNavController()
                val viewModel: ToolViewModel = viewModel()
                val tools by viewModel.tools.collectAsStateWithLifecycle()

                NavHost(navController = navController, startDestination = Routes.LIST) {
                    composable(Routes.LIST) {
                        ToolListScreen(
                            viewModel = viewModel,
                            onToolClick = { tool ->
                                navController.navigate(Routes.tool(tool.id))
                            },
                        )
                    }

                    composable(
                        route = Routes.TOOL,
                        arguments = listOf(navArgument("slug") { type = NavType.StringType }),
                        deepLinks = listOf(
                            navDeepLink { uriPattern = "smalltools://open/{slug}" }
                        ),
                    ) { backStackEntry ->
                        val slug = backStackEntry.arguments?.getString("slug") ?: return@composable
                        val tool = tools.firstOrNull { it.id == slug } ?: return@composable
                        ToolViewerScreen(
                            tool = tool,
                            viewModel = viewModel,
                            onBack = { navController.popBackStack() },
                        )
                    }
                }

                // Handle slug from a dynamic shortcut or widget tap.
                // Uses currentIntent (backed by mutableStateOf) so onNewIntent triggers recomposition.
                val slug = currentIntent?.getStringExtra(ShortcutsManager.EXTRA_SLUG)
                if (slug != null) {
                    LaunchedEffect(slug) {
                        navController.navigate(Routes.tool(slug))
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        currentIntent = intent   // triggers recomposition → LaunchedEffect picks up the new slug
    }

    override fun onStop() {
        super.onStop()
        // Mirror iOS: .onChange(of: scenePhase) { .background -> QuickActions.update(with: store) }
        ShortcutsManager.update(this, ViewModelProvider(this)[ToolViewModel::class.java].downloadedTools())
    }
}

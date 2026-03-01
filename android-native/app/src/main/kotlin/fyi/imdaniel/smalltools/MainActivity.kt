package fyi.imdaniel.smalltools

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.navigation.navDeepLink
import fyi.imdaniel.smalltools.shortcuts.ShortcutsManager
import fyi.imdaniel.smalltools.ui.screens.ToolListScreen
import fyi.imdaniel.smalltools.ui.screens.ToolViewerScreen
import fyi.imdaniel.smalltools.ui.theme.SmallToolsTheme
import fyi.imdaniel.smalltools.viewmodel.ToolViewModel

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            SmallToolsTheme {
                val navController = rememberNavController()
                val viewModel: ToolViewModel = viewModel()

                NavHost(navController = navController, startDestination = "list") {
                    composable("list") {
                        ToolListScreen(
                            viewModel = viewModel,
                            onToolClick = { tool ->
                                navController.navigate("tool/${tool.id}")
                            },
                        )
                    }

                    composable(
                        route = "tool/{slug}",
                        arguments = listOf(navArgument("slug") { type = NavType.StringType }),
                        deepLinks = listOf(
                            navDeepLink { uriPattern = "smalltools://open/{slug}" }
                        ),
                    ) { backStackEntry ->
                        val slug = backStackEntry.arguments?.getString("slug") ?: return@composable
                        // Look up tool; if manifest not loaded yet, navigate back
                        val tool = viewModel.tools.value.firstOrNull { it.id == slug }
                            ?: return@composable
                        ToolViewerScreen(
                            tool = tool,
                            viewModel = viewModel,
                            onBack = { navController.popBackStack() },
                        )
                    }
                }

                // Handle slug from dynamic shortcut or widget tap (not a deep link URI)
                val slug = extractSlugFromIntent(intent)
                if (slug != null) {
                    androidx.compose.runtime.LaunchedEffect(slug) {
                        navController.navigate("tool/$slug")
                    }
                }
            }
        }
    }

    // Handle the case where the app is already running (singleTop) and a new shortcut/widget is tapped
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // The LaunchedEffect above will recompose with the new slug on the next recomposition
    }

    override fun onStop() {
        super.onStop()
        // Mirror iOS: .onChange(of: scenePhase) { .background -> QuickActions.update(with: store) }
        val viewModel = androidx.lifecycle.ViewModelProvider(this)[ToolViewModel::class.java]
        ShortcutsManager.update(this, viewModel.downloadedTools())
    }

    private fun extractSlugFromIntent(intent: Intent?): String? {
        // From dynamic shortcut extra
        val shortcutSlug = intent?.getStringExtra(ShortcutsManager.EXTRA_SLUG)
        if (shortcutSlug != null) return shortcutSlug
        // Deep links are handled by Navigation Compose automatically via navDeepLink
        return null
    }
}

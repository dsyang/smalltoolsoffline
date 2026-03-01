package fyi.imdaniel.smalltools.shortcuts

import android.content.Context
import android.content.Intent
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import fyi.imdaniel.smalltools.MainActivity
import fyi.imdaniel.smalltools.R
import fyi.imdaniel.smalltools.model.Tool

object ShortcutsManager {

    const val EXTRA_SLUG = "slug"
    /** Shared intent flags used by both shortcuts and the widget to launch MainActivity. */
    const val LAUNCH_FLAGS = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP

    fun update(context: Context, downloadedTools: List<Tool>) {
        val maxCount = minOf(ShortcutManagerCompat.getMaxShortcutCountPerActivity(context), 4)
        val shortcuts = downloadedTools.take(maxCount).map { tool ->
            ShortcutInfoCompat.Builder(context, "tool_${tool.id}")
                .setShortLabel(tool.title)
                .setLongLabel(tool.title)
                .setIcon(IconCompat.createWithResource(context, R.drawable.ic_shortcut_tool))
                .setIntent(
                    Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        putExtra(EXTRA_SLUG, tool.id)
                        flags = LAUNCH_FLAGS
                    }
                )
                .build()
        }
        ShortcutManagerCompat.setDynamicShortcuts(context, shortcuts)
    }
}

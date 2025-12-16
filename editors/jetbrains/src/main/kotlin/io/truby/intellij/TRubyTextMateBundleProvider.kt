package io.truby.intellij

import org.jetbrains.plugins.textmate.api.TextMateBundleProvider
import java.nio.file.Path

/**
 * TextMate bundle provider for T-Ruby syntax highlighting.
 *
 * This class provides the TextMate grammar bundle to JetBrains IDEs,
 * enabling syntax highlighting for .trb and .d.trb files.
 */
class TRubyTextMateBundleProvider : TextMateBundleProvider {
    override fun getBundles(): List<TextMateBundleProvider.PluginBundle> {
        val bundlePath = javaClass.getResource("/syntaxes")?.toURI()?.let { Path.of(it) }
            ?: return emptyList()

        return listOf(
            TextMateBundleProvider.PluginBundle("T-Ruby", bundlePath)
        )
    }
}

package io.truby.intellij.lsp

import com.intellij.openapi.project.Project
import com.redhat.devtools.lsp4ij.server.ProcessStreamConnectionProvider
import io.truby.intellij.settings.TRubySettings

/**
 * Connection provider for the T-Ruby language server.
 *
 * Launches `trc --lsp` and communicates via stdio.
 */
class TRubyLspConnectionProvider(private val project: Project) : ProcessStreamConnectionProvider() {

    init {
        val settings = TRubySettings.instance
        val trcPath = settings.trcPath.ifEmpty { "trc" }

        val commands = mutableListOf(trcPath, "--lsp")

        setCommands(commands)
        setWorkingDirectory(project.basePath)
    }

    override fun toString(): String {
        return "T-Ruby Language Server: ${commands.joinToString(" ")}"
    }
}

package io.truby.intellij.lsp

import com.intellij.openapi.project.Project
import com.redhat.devtools.lsp4ij.LanguageServerFactory
import com.redhat.devtools.lsp4ij.client.LanguageClientImpl
import com.redhat.devtools.lsp4ij.server.StreamConnectionProvider
import org.eclipse.lsp4j.services.LanguageServer

/**
 * Factory for creating T-Ruby LSP server connections.
 *
 * This factory is registered in plugin.xml and provides LSP4IJ
 * with the connection provider for the T-Ruby language server.
 */
class TRubyLspServerFactory : LanguageServerFactory {

    override fun createConnectionProvider(project: Project): StreamConnectionProvider {
        return TRubyLspConnectionProvider(project)
    }

    override fun createLanguageClient(project: Project): LanguageClientImpl {
        return TRubyLanguageClient(project)
    }

    override fun getServerInterface(): Class<out LanguageServer> {
        return LanguageServer::class.java
    }
}

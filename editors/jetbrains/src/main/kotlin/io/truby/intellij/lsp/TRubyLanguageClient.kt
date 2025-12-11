package io.truby.intellij.lsp

import com.intellij.openapi.project.Project
import com.redhat.devtools.lsp4ij.client.LanguageClientImpl

/**
 * Custom language client for T-Ruby LSP server.
 *
 * Extends the default LSP4IJ client to handle T-Ruby specific features if needed.
 */
class TRubyLanguageClient(project: Project) : LanguageClientImpl(project) {
    // Currently uses default implementation
    // Can be extended for T-Ruby specific client capabilities
}

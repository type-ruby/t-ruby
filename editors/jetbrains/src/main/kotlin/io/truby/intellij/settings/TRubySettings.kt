package io.truby.intellij.settings

import com.intellij.openapi.application.ApplicationManager
import com.intellij.openapi.components.PersistentStateComponent
import com.intellij.openapi.components.State
import com.intellij.openapi.components.Storage
import com.intellij.util.xmlb.XmlSerializerUtil

/**
 * Persistent settings for the T-Ruby plugin.
 */
@State(
    name = "TRubySettings",
    storages = [Storage("truby.xml")]
)
class TRubySettings : PersistentStateComponent<TRubySettings> {

    /**
     * Path to the T-Ruby compiler (trc) executable.
     * If empty, uses "trc" from PATH.
     */
    var trcPath: String = "trc"

    /**
     * Enable LSP features (completion, diagnostics, etc.).
     */
    var enableLsp: Boolean = true

    /**
     * Enable real-time diagnostics.
     */
    var enableDiagnostics: Boolean = true

    /**
     * Enable code completion.
     */
    var enableCompletion: Boolean = true

    override fun getState(): TRubySettings = this

    override fun loadState(state: TRubySettings) {
        XmlSerializerUtil.copyBean(state, this)
    }

    companion object {
        val instance: TRubySettings
            get() = ApplicationManager.getApplication().getService(TRubySettings::class.java)
    }
}

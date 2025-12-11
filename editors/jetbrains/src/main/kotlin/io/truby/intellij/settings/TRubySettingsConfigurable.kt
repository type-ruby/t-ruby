package io.truby.intellij.settings

import com.intellij.openapi.fileChooser.FileChooserDescriptorFactory
import com.intellij.openapi.options.Configurable
import com.intellij.openapi.ui.TextFieldWithBrowseButton
import com.intellij.ui.components.JBCheckBox
import com.intellij.ui.components.JBLabel
import com.intellij.util.ui.FormBuilder
import javax.swing.JComponent
import javax.swing.JPanel

/**
 * Settings UI for T-Ruby plugin configuration.
 */
class TRubySettingsConfigurable : Configurable {
    private var panel: JPanel? = null
    private var trcPathField: TextFieldWithBrowseButton? = null
    private var enableLspCheckbox: JBCheckBox? = null
    private var enableDiagnosticsCheckbox: JBCheckBox? = null
    private var enableCompletionCheckbox: JBCheckBox? = null

    override fun getDisplayName(): String = "T-Ruby"

    override fun createComponent(): JComponent {
        trcPathField = TextFieldWithBrowseButton().apply {
            addBrowseFolderListener(
                "Select T-Ruby Compiler",
                "Select the path to the trc executable",
                null,
                FileChooserDescriptorFactory.createSingleFileDescriptor()
            )
        }

        enableLspCheckbox = JBCheckBox("Enable Language Server Protocol")
        enableDiagnosticsCheckbox = JBCheckBox("Enable real-time diagnostics")
        enableCompletionCheckbox = JBCheckBox("Enable code completion")

        panel = FormBuilder.createFormBuilder()
            .addLabeledComponent(JBLabel("T-Ruby compiler (trc) path:"), trcPathField!!, 1, false)
            .addComponent(JBLabel("<html><small>Leave empty to use 'trc' from PATH</small></html>"))
            .addSeparator()
            .addComponent(enableLspCheckbox!!)
            .addComponent(enableDiagnosticsCheckbox!!)
            .addComponent(enableCompletionCheckbox!!)
            .addComponentFillVertically(JPanel(), 0)
            .panel

        return panel!!
    }

    override fun isModified(): Boolean {
        val settings = TRubySettings.instance
        return trcPathField?.text != settings.trcPath ||
                enableLspCheckbox?.isSelected != settings.enableLsp ||
                enableDiagnosticsCheckbox?.isSelected != settings.enableDiagnostics ||
                enableCompletionCheckbox?.isSelected != settings.enableCompletion
    }

    override fun apply() {
        val settings = TRubySettings.instance
        settings.trcPath = trcPathField?.text ?: "trc"
        settings.enableLsp = enableLspCheckbox?.isSelected ?: true
        settings.enableDiagnostics = enableDiagnosticsCheckbox?.isSelected ?: true
        settings.enableCompletion = enableCompletionCheckbox?.isSelected ?: true
    }

    override fun reset() {
        val settings = TRubySettings.instance
        trcPathField?.text = settings.trcPath
        enableLspCheckbox?.isSelected = settings.enableLsp
        enableDiagnosticsCheckbox?.isSelected = settings.enableDiagnostics
        enableCompletionCheckbox?.isSelected = settings.enableCompletion
    }

    override fun disposeUIResources() {
        panel = null
        trcPathField = null
        enableLspCheckbox = null
        enableDiagnosticsCheckbox = null
        enableCompletionCheckbox = null
    }
}

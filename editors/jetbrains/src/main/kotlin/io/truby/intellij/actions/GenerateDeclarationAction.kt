package io.truby.intellij.actions

import com.intellij.execution.configurations.GeneralCommandLine
import com.intellij.execution.process.OSProcessHandler
import com.intellij.execution.process.ProcessHandler
import com.intellij.execution.process.ProcessTerminatedListener
import com.intellij.openapi.actionSystem.ActionUpdateThread
import com.intellij.openapi.actionSystem.AnAction
import com.intellij.openapi.actionSystem.AnActionEvent
import com.intellij.openapi.actionSystem.CommonDataKeys
import com.intellij.openapi.fileEditor.FileDocumentManager
import com.intellij.openapi.project.Project
import com.intellij.openapi.wm.ToolWindowManager
import io.truby.intellij.TRubyIcons
import io.truby.intellij.settings.TRubySettings

/**
 * Action to generate a T-Ruby declaration file (.d.trb) from the current file.
 */
class GenerateDeclarationAction : AnAction(
    "Generate Declaration File",
    "Generate .d.trb declaration file from current T-Ruby file",
    TRubyIcons.DECLARATION_FILE
) {
    override fun getActionUpdateThread(): ActionUpdateThread = ActionUpdateThread.BGT

    override fun actionPerformed(e: AnActionEvent) {
        val project = e.project ?: return
        val virtualFile = e.getData(CommonDataKeys.VIRTUAL_FILE) ?: return

        // Save the file first
        FileDocumentManager.getInstance().saveAllDocuments()

        val settings = TRubySettings.instance
        val trcPath = settings.trcPath.ifEmpty { "trc" }

        val commandLine = GeneralCommandLine(trcPath, "--decl", virtualFile.path)
            .withWorkDirectory(project.basePath)
            .withCharset(Charsets.UTF_8)

        runCommand(project, commandLine, "T-Ruby Declaration: ${virtualFile.name}")
    }

    override fun update(e: AnActionEvent) {
        val file = e.getData(CommonDataKeys.VIRTUAL_FILE)
        // Only enable for .trb files (not .d.trb since those are already declarations)
        val isTRubySource = file?.extension == "trb" && !file.name.endsWith(".d.trb")

        e.presentation.isEnabledAndVisible = e.project != null && isTRubySource
    }

    private fun runCommand(project: Project, commandLine: GeneralCommandLine, title: String) {
        try {
            val processHandler: ProcessHandler = OSProcessHandler(commandLine)
            ProcessTerminatedListener.attach(processHandler)

            // Show output in Run tool window
            val toolWindowManager = ToolWindowManager.getInstance(project)
            val toolWindow = toolWindowManager.getToolWindow("Run")

            toolWindow?.show {
                val contentManager = toolWindow.contentManager
                val consoleView = com.intellij.execution.impl.ConsoleViewImpl(project, true)
                consoleView.attachToProcess(processHandler)

                val content = contentManager.factory.createContent(consoleView.component, title, false)
                contentManager.addContent(content)
                contentManager.setSelectedContent(content)

                processHandler.startNotify()
            }
        } catch (ex: Exception) {
            com.intellij.openapi.ui.Messages.showErrorDialog(
                project,
                "Failed to generate declaration file: ${ex.message}",
                "T-Ruby Declaration Error"
            )
        }
    }
}

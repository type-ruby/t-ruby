package io.truby.intellij.actions

import com.intellij.execution.configurations.GeneralCommandLine
import com.intellij.execution.process.OSProcessHandler
import com.intellij.execution.process.ProcessHandler
import com.intellij.execution.process.ProcessTerminatedListener
import com.intellij.execution.ui.ConsoleView
import com.intellij.execution.ui.ConsoleViewContentType
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
 * Action to compile the current T-Ruby file to Ruby.
 */
class CompileTRubyFileAction : AnAction(
    "Compile T-Ruby File",
    "Compile the current T-Ruby file to Ruby",
    TRubyIcons.FILE
) {
    override fun getActionUpdateThread(): ActionUpdateThread = ActionUpdateThread.BGT

    override fun actionPerformed(e: AnActionEvent) {
        val project = e.project ?: return
        val virtualFile = e.getData(CommonDataKeys.VIRTUAL_FILE) ?: return

        // Save the file first
        FileDocumentManager.getInstance().saveAllDocuments()

        val settings = TRubySettings.instance
        val trcPath = settings.trcPath.ifEmpty { "trc" }

        val commandLine = GeneralCommandLine(trcPath, virtualFile.path)
            .withWorkDirectory(project.basePath)
            .withCharset(Charsets.UTF_8)

        runCommand(project, commandLine, "T-Ruby Compile: ${virtualFile.name}")
    }

    override fun update(e: AnActionEvent) {
        val file = e.getData(CommonDataKeys.VIRTUAL_FILE)
        val isTRubyFile = file?.extension == "trb" ||
                (file?.name?.endsWith(".d.trb") == true)

        e.presentation.isEnabledAndVisible = e.project != null && isTRubyFile
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
                "Failed to run T-Ruby compiler: ${ex.message}",
                "T-Ruby Compile Error"
            )
        }
    }
}

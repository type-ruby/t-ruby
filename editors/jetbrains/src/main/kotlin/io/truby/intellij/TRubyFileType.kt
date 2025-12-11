package io.truby.intellij

import com.intellij.openapi.fileTypes.LanguageFileType
import javax.swing.Icon

/**
 * File type for T-Ruby source files (.trb).
 */
object TRubyFileType : LanguageFileType(TRubyLanguage) {
    private fun readResolve(): Any = TRubyFileType

    override fun getName(): String = "T-Ruby"

    override fun getDescription(): String = "T-Ruby source file"

    override fun getDefaultExtension(): String = "trb"

    override fun getIcon(): Icon = TRubyIcons.FILE
}

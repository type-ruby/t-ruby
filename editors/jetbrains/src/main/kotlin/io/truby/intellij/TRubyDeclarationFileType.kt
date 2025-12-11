package io.truby.intellij

import com.intellij.openapi.fileTypes.LanguageFileType
import javax.swing.Icon

/**
 * File type for T-Ruby declaration files (.d.trb).
 *
 * Declaration files contain only type signatures without implementation,
 * similar to TypeScript's .d.ts files.
 */
object TRubyDeclarationFileType : LanguageFileType(TRubyLanguage) {
    private fun readResolve(): Any = TRubyDeclarationFileType

    override fun getName(): String = "T-Ruby Declaration"

    override fun getDescription(): String = "T-Ruby declaration file"

    override fun getDefaultExtension(): String = "d.trb"

    override fun getIcon(): Icon = TRubyIcons.DECLARATION_FILE
}

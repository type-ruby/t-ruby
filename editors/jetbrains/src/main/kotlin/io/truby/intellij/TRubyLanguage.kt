package io.truby.intellij

import com.intellij.lang.Language

/**
 * T-Ruby language definition for IntelliJ Platform.
 *
 * T-Ruby is a typed superset of Ruby, similar to how TypeScript extends JavaScript.
 */
object TRubyLanguage : Language("T-Ruby") {
    private fun readResolve(): Any = TRubyLanguage

    override fun getDisplayName(): String = "T-Ruby"

    override fun isCaseSensitive(): Boolean = true
}

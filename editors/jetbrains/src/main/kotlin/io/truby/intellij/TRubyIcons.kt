package io.truby.intellij

import com.intellij.openapi.util.IconLoader
import javax.swing.Icon

/**
 * Icon definitions for T-Ruby plugin.
 */
object TRubyIcons {
    @JvmField
    val FILE: Icon = IconLoader.getIcon("/icons/truby.svg", TRubyIcons::class.java)

    @JvmField
    val DECLARATION_FILE: Icon = IconLoader.getIcon("/icons/truby-decl.svg", TRubyIcons::class.java)
}

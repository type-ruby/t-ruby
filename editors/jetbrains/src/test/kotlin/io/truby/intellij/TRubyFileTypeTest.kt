package io.truby.intellij

import com.intellij.testFramework.fixtures.BasePlatformTestCase
import org.junit.jupiter.api.Assertions.*

/**
 * Tests for T-Ruby file type registration and recognition.
 */
class TRubyFileTypeTest : BasePlatformTestCase() {

    fun testTRubyFileTypeRegistered() {
        val fileType = TRubyFileType.INSTANCE
        assertNotNull(fileType)
        assertEquals("T-Ruby", fileType.name)
        assertEquals("T-Ruby source file", fileType.description)
        assertEquals("trb", fileType.defaultExtension)
    }

    fun testTRubyDeclarationFileTypeRegistered() {
        val fileType = TRubyDeclarationFileType.INSTANCE
        assertNotNull(fileType)
        assertEquals("T-Ruby Declaration", fileType.name)
        assertEquals("T-Ruby declaration file", fileType.description)
        assertEquals("d.trb", fileType.defaultExtension)
    }

    fun testTRubyLanguageRegistered() {
        val language = TRubyLanguage.INSTANCE
        assertNotNull(language)
        assertEquals("T-Ruby", language.id)
    }

    fun testFileRecognition() {
        // Create a test .trb file
        val file = myFixture.configureByText("test.trb", """
            def hello(name: String): String
              "Hello, #{name}!"
            end
        """.trimIndent())

        assertEquals(TRubyFileType.INSTANCE, file.virtualFile.fileType)
    }

    fun testDeclarationFileRecognition() {
        // Create a test .d.trb file
        val file = myFixture.configureByText("types.d.trb", """
            type UserID = Integer

            interface User
              def name(): String
            end
        """.trimIndent())

        assertEquals(TRubyDeclarationFileType.INSTANCE, file.virtualFile.fileType)
    }
}

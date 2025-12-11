package io.truby.intellij

import com.intellij.testFramework.fixtures.BasePlatformTestCase
import io.truby.intellij.settings.TRubySettings
import org.junit.jupiter.api.Assertions.*

/**
 * Tests for T-Ruby settings and configuration.
 */
class TRubySettingsTest : BasePlatformTestCase() {

    fun testDefaultSettings() {
        val settings = TRubySettings.getInstance()
        assertNotNull(settings)

        // Check default values
        assertEquals("trc", settings.state.compilerPath)
        assertTrue(settings.state.enableLsp)
    }

    fun testSettingsPersistence() {
        val settings = TRubySettings.getInstance()

        // Modify settings
        settings.state.compilerPath = "/custom/path/trc"
        settings.state.enableLsp = false

        // Verify changes
        assertEquals("/custom/path/trc", settings.state.compilerPath)
        assertFalse(settings.state.enableLsp)

        // Reset to defaults for other tests
        settings.state.compilerPath = "trc"
        settings.state.enableLsp = true
    }
}

plugins {
    id("java")
    id("org.jetbrains.kotlin.jvm") version "1.9.25"
    id("org.jetbrains.intellij.platform") version "2.2.1"
}

group = "io.truby"
version = "0.1.0"

repositories {
    mavenCentral()
    intellijPlatform {
        defaultRepositories()
    }
}

dependencies {
    intellijPlatform {
        intellijIdeaCommunity("2024.2")
        plugin("com.redhat.devtools.lsp4ij:0.19.0")
        pluginVerifier()
        zipSigner()
    }
}

intellijPlatform {
    pluginConfiguration {
        id = "io.truby.t-ruby"
        name = "T-Ruby"
        version = project.version.toString()
        description = """
            T-Ruby language support for JetBrains IDEs.

            Features:
            <ul>
                <li>Syntax highlighting for .trb and .d.trb files</li>
                <li>Code completion with type inference</li>
                <li>Real-time diagnostics</li>
                <li>Go to definition</li>
                <li>Hover information</li>
            </ul>
        """.trimIndent()
        changeNotes = """
            <ul>
                <li>Initial release</li>
                <li>LSP integration via LSP4IJ</li>
                <li>TextMate grammar support</li>
            </ul>
        """.trimIndent()
        vendor {
            name = "T-Ruby"
            email = "support@type-ruby.io"
            url = "https://type-ruby.github.io"
        }
        ideaVersion {
            sinceBuild = "242"
            untilBuild = "253.*"
        }
    }

    signing {
        certificateChain = providers.environmentVariable("CERTIFICATE_CHAIN")
        privateKey = providers.environmentVariable("PRIVATE_KEY")
        password = providers.environmentVariable("PRIVATE_KEY_PASSWORD")
    }

    publishing {
        token = providers.environmentVariable("PUBLISH_TOKEN")
    }
}

kotlin {
    jvmToolchain(21)
}

tasks {
    buildSearchableOptions {
        enabled = false
    }
}

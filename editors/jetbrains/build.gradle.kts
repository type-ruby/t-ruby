plugins {
    id("java")
    id("org.jetbrains.kotlin.jvm") version "1.9.25"
    id("org.jetbrains.intellij.platform") version "2.2.1"
}

group = "io.truby"
version = "0.1.4"

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
        bundledPlugin("org.jetbrains.plugins.textmate")
        pluginVerifier()
        zipSigner()
        testFramework(org.jetbrains.intellij.platform.gradle.TestFrameworkType.Platform)
    }

    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

intellijPlatform {
    pluginConfiguration {
        id = "io.truby.t-ruby"
        name = "T-Ruby"
        version = project.version.toString()
        description = """
            <p><b>T-Ruby</b> is a typed superset of Ruby, inspired by TypeScript.
            Add static type checking to your Ruby projects and catch errors before runtime.</p>

            <h3>Features</h3>
            <ul>
                <li><b>Syntax Highlighting</b> - Full support for .trb and .d.trb files</li>
                <li><b>Code Completion</b> - Type-aware autocompletion</li>
                <li><b>Real-time Diagnostics</b> - See type errors as you type</li>
                <li><b>Go to Definition</b> - Navigate to symbols with Ctrl+Click</li>
                <li><b>Hover Information</b> - View type information on hover</li>
                <li><b>Compile Commands</b> - Compile .trb to .rb directly from IDE</li>
            </ul>

            <h3>Requirements</h3>
            <ul>
                <li><a href="https://rubygems.org/gems/t-ruby">T-Ruby compiler</a> (gem install t-ruby)</li>
                <li><a href="https://plugins.jetbrains.com/plugin/23257-lsp4ij">LSP4IJ plugin</a></li>
            </ul>

            <h3>Quick Start</h3>
            <ol>
                <li>Install T-Ruby: <code>gem install t-ruby</code></li>
                <li>Install LSP4IJ plugin</li>
                <li>Install this plugin</li>
                <li>Create a .trb file and start coding!</li>
            </ol>

            <p>Learn more at <a href="https://type-ruby.github.io">type-ruby.github.io</a></p>
        """.trimIndent()
        changeNotes = """
            <h3>0.1.2</h3>
            <ul>
                <li>Extended IDE compatibility (2024.2 - 2025.4)</li>
                <li>Improved plugin description and documentation</li>
                <li>Added plugin icon for JetBrains Marketplace</li>
            </ul>

            <h3>0.1.1 - Initial Release</h3>
            <ul>
                <li>JetBrains Marketplace initial release</li>
                <li>LSP integration via LSP4IJ for language server support</li>
                <li>TextMate grammar for syntax highlighting</li>
                <li>File type support for .trb and .d.trb</li>
                <li>Compile T-Ruby file action (Ctrl+Shift+T / Cmd+Shift+T)</li>
                <li>Generate declaration file action (Ctrl+Shift+D / Cmd+Shift+D)</li>
            </ul>
        """.trimIndent()
        vendor {
            name = "T-Ruby"
            email = "support@type-ruby.io"
            url = "https://type-ruby.github.io"
        }
        ideaVersion {
            sinceBuild = "242"
            untilBuild = "254.*"
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

    test {
        useJUnitPlatform()
    }
}

import * as vscode from 'vscode';
import * as path from 'path';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;

export function activate(context: vscode.ExtensionContext) {
    console.log('T-Ruby extension is now active');

    // Get configuration
    const config = vscode.workspace.getConfiguration('t-ruby');
    const lspPath = config.get<string>('lspPath', 'trc');
    const enableLSP = config.get<boolean>('enableLSP', true);

    if (enableLSP) {
        // Start the language server
        startLanguageServer(context, lspPath);
    }

    // Register commands
    registerCommands(context, lspPath);
}

function startLanguageServer(context: vscode.ExtensionContext, lspPath: string) {
    // Server options - run the T-Ruby LSP server
    const serverOptions: ServerOptions = {
        run: {
            command: lspPath,
            args: ['--lsp'],
            transport: TransportKind.stdio
        },
        debug: {
            command: lspPath,
            args: ['--lsp'],
            transport: TransportKind.stdio
        }
    };

    // Client options
    const clientOptions: LanguageClientOptions = {
        documentSelector: [
            { scheme: 'file', language: 't-ruby' },
            { scheme: 'file', pattern: '**/*.trb' },
            { scheme: 'file', pattern: '**/*.d.trb' }
        ],
        synchronize: {
            fileEvents: vscode.workspace.createFileSystemWatcher('**/*.{trb,d.trb}')
        },
        outputChannelName: 'T-Ruby Language Server'
    };

    // Create and start the language client
    client = new LanguageClient(
        't-ruby-lsp',
        'T-Ruby Language Server',
        serverOptions,
        clientOptions
    );

    // Start the client
    client.start().then(() => {
        console.log('T-Ruby Language Server started');
    }).catch((error) => {
        console.error('Failed to start T-Ruby Language Server:', error);
        vscode.window.showErrorMessage(
            `Failed to start T-Ruby Language Server. Make sure 'trc' is installed and in your PATH. Error: ${error.message}`
        );
    });

    context.subscriptions.push({
        dispose: () => {
            if (client) {
                return client.stop();
            }
        }
    });
}

function registerCommands(context: vscode.ExtensionContext, lspPath: string) {
    // Compile command
    const compileCommand = vscode.commands.registerCommand('t-ruby.compile', async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor) {
            vscode.window.showWarningMessage('No active file to compile');
            return;
        }

        const filePath = editor.document.fileName;
        if (!filePath.endsWith('.trb')) {
            vscode.window.showWarningMessage('Current file is not a .trb file');
            return;
        }

        // Save the file first
        await editor.document.save();

        // Run the compiler
        const terminal = vscode.window.createTerminal('T-Ruby Compile');
        terminal.show();
        terminal.sendText(`${lspPath} "${filePath}"`);
    });

    // Generate declaration command
    const generateDeclCommand = vscode.commands.registerCommand('t-ruby.generateDeclaration', async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor) {
            vscode.window.showWarningMessage('No active file');
            return;
        }

        const filePath = editor.document.fileName;
        if (!filePath.endsWith('.trb')) {
            vscode.window.showWarningMessage('Current file is not a .trb file');
            return;
        }

        // Save the file first
        await editor.document.save();

        // Run the declaration generator
        const terminal = vscode.window.createTerminal('T-Ruby Declaration');
        terminal.show();
        terminal.sendText(`${lspPath} --decl "${filePath}"`);
    });

    // Restart LSP command
    const restartLSPCommand = vscode.commands.registerCommand('t-ruby.restartLSP', async () => {
        if (client) {
            await client.stop();
            await client.start();
            vscode.window.showInformationMessage('T-Ruby Language Server restarted');
        } else {
            vscode.window.showWarningMessage('Language Server is not running');
        }
    });

    context.subscriptions.push(compileCommand, generateDeclCommand, restartLSPCommand);
}

export function deactivate(): Thenable<void> | undefined {
    if (!client) {
        return undefined;
    }
    return client.stop();
}

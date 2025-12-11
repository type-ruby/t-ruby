import * as assert from 'assert';
import * as vscode from 'vscode';

suite('T-Ruby Extension Test Suite', () => {
    vscode.window.showInformationMessage('Start all tests.');

    test('Extension should be present', () => {
        assert.ok(vscode.extensions.getExtension('t-ruby.t-ruby'));
    });

    test('Extension should activate', async () => {
        const extension = vscode.extensions.getExtension('t-ruby.t-ruby');
        assert.ok(extension);

        if (!extension.isActive) {
            await extension.activate();
        }

        assert.ok(extension.isActive);
    });

    test('Commands should be registered', async () => {
        const commands = await vscode.commands.getCommands(true);

        assert.ok(commands.includes('t-ruby.compile'), 'compile command should be registered');
        assert.ok(commands.includes('t-ruby.generateDeclaration'), 'generateDeclaration command should be registered');
        assert.ok(commands.includes('t-ruby.restartLSP'), 'restartLSP command should be registered');
    });

    test('T-Ruby language should be registered', () => {
        const languages = vscode.languages.getLanguages();
        // Language registration is async, so we just check the extension contributes it
        const extension = vscode.extensions.getExtension('t-ruby.t-ruby');
        assert.ok(extension);

        const contributes = extension.packageJSON.contributes;
        assert.ok(contributes.languages);
        assert.ok(contributes.languages.some((lang: any) => lang.id === 't-ruby'));
    });

    test('Grammar should be registered', () => {
        const extension = vscode.extensions.getExtension('t-ruby.t-ruby');
        assert.ok(extension);

        const contributes = extension.packageJSON.contributes;
        assert.ok(contributes.grammars);
        assert.ok(contributes.grammars.some((grammar: any) => grammar.language === 't-ruby'));
    });

    test('Configuration should be available', () => {
        const config = vscode.workspace.getConfiguration('t-ruby');

        // Check default values
        assert.strictEqual(config.get('lspPath'), 'trc');
        assert.strictEqual(config.get('enableLSP'), true);
        assert.strictEqual(config.get('diagnostics.enable'), true);
        assert.strictEqual(config.get('completion.enable'), true);
    });

    test('File extensions should be associated', () => {
        const extension = vscode.extensions.getExtension('t-ruby.t-ruby');
        assert.ok(extension);

        const languages = extension.packageJSON.contributes.languages;
        const tRubyLang = languages.find((lang: any) => lang.id === 't-ruby');

        assert.ok(tRubyLang);
        assert.ok(tRubyLang.extensions.includes('.trb'));
        assert.ok(tRubyLang.extensions.includes('.d.trb'));
    });
});

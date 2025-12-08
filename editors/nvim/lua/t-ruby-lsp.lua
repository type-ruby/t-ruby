-- T-Ruby LSP configuration for Neovim
-- Add this to your init.lua or init.vim (via lua heredoc)

local M = {}

-- Default configuration
M.config = {
    cmd = { "trc", "--lsp" },
    filetypes = { "truby", "trb" },
    root_dir = function(fname)
        local lspconfig = require("lspconfig")
        return lspconfig.util.root_pattern(".trb.yml", ".git")(fname)
            or lspconfig.util.find_git_ancestor(fname)
            or vim.fn.getcwd()
    end,
    settings = {},
}

-- Setup function to register T-Ruby LSP with nvim-lspconfig
function M.setup(opts)
    opts = opts or {}
    local config = vim.tbl_deep_extend("force", M.config, opts)

    -- Check if lspconfig is available
    local ok, lspconfig = pcall(require, "lspconfig")
    if not ok then
        vim.notify("nvim-lspconfig is required for T-Ruby LSP support", vim.log.levels.ERROR)
        return
    end

    -- Register T-Ruby LSP configuration
    local configs = require("lspconfig.configs")
    if not configs.t_ruby then
        configs.t_ruby = {
            default_config = {
                cmd = config.cmd,
                filetypes = config.filetypes,
                root_dir = config.root_dir,
                settings = config.settings,
            },
        }
    end

    -- Setup the server
    lspconfig.t_ruby.setup(config)

    -- Set up filetype associations
    vim.filetype.add({
        extension = {
            trb = "truby",
            ["d.trb"] = "truby",
        },
    })
end

-- Manual setup without nvim-lspconfig (using vim.lsp.start)
function M.setup_manual(opts)
    opts = opts or {}
    local config = vim.tbl_deep_extend("force", M.config, opts)

    -- Create autocommand for T-Ruby files
    vim.api.nvim_create_autocmd("FileType", {
        pattern = { "truby", "trb" },
        callback = function(args)
            vim.lsp.start({
                name = "t-ruby-lsp",
                cmd = config.cmd,
                root_dir = config.root_dir(args.file),
                settings = config.settings,
            })
        end,
    })

    -- Set up filetype associations
    vim.filetype.add({
        extension = {
            trb = "truby",
            ["d.trb"] = "truby",
        },
    })
end

-- Utility function to check if T-Ruby LSP is running
function M.is_active()
    local clients = vim.lsp.get_clients({ name = "t_ruby" })
    return #clients > 0
end

-- Compile current file
function M.compile()
    local file = vim.fn.expand("%:p")
    if not file:match("%.trb$") then
        vim.notify("Current file is not a .trb file", vim.log.levels.WARN)
        return
    end
    vim.cmd("!" .. M.config.cmd[1] .. " " .. vim.fn.shellescape(file))
end

-- Generate declaration file
function M.generate_declaration()
    local file = vim.fn.expand("%:p")
    if not file:match("%.trb$") then
        vim.notify("Current file is not a .trb file", vim.log.levels.WARN)
        return
    end
    vim.cmd("!" .. M.config.cmd[1] .. " --decl " .. vim.fn.shellescape(file))
end

-- Create user commands
function M.create_commands()
    vim.api.nvim_create_user_command("TRubyCompile", function()
        M.compile()
    end, { desc = "Compile current T-Ruby file" })

    vim.api.nvim_create_user_command("TRubyDecl", function()
        M.generate_declaration()
    end, { desc = "Generate declaration file for current T-Ruby file" })

    vim.api.nvim_create_user_command("TRubyLspInfo", function()
        if M.is_active() then
            vim.notify("T-Ruby LSP is active", vim.log.levels.INFO)
        else
            vim.notify("T-Ruby LSP is not active", vim.log.levels.WARN)
        end
    end, { desc = "Check T-Ruby LSP status" })
end

return M

require("fran.set")
require("fran.remap")
require("fran.lazy_init")

local function trim_empty_lines(lines)
    local start_idx = 1
    local end_idx = #lines

    while start_idx <= end_idx and lines[start_idx]:match("^%s*$") do
        start_idx = start_idx + 1
    end

    while end_idx >= start_idx and lines[end_idx]:match("^%s*$") do
        end_idx = end_idx - 1
    end

    local trimmed = {}
    for i = start_idx, end_idx do
        trimmed[#trimmed + 1] = lines[i]
    end
    return trimmed
end

local function open_plain_float(lines)
    local cleaned = trim_empty_lines(lines or {})
    if vim.tbl_isempty(cleaned) then
        return
    end

    local bufnr, winid = vim.lsp.util.open_floating_preview(cleaned, "text", {
        border = "rounded",
        focusable = false,
    })
    if bufnr then
        vim.bo[bufnr].modifiable = false
        pcall(vim.treesitter.stop, bufnr)
    end
    return bufnr, winid
end

local function hover_plain()
    local params = vim.lsp.util.make_position_params(0, "utf-8")
    vim.lsp.buf_request(0, "textDocument/hover", params, function(err, result, ctx)
        if err then
            vim.notify(err.message or tostring(err), vim.log.levels.ERROR)
            return
        end

        if not (result and result.contents) then
            return
        end

        local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
        open_plain_float(lines)
    end)
end

vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
    if err then
        vim.notify(err.message or tostring(err), vim.log.levels.ERROR)
        return
    end

    if not (result and result.contents) then
        return
    end

    local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
    lines = trim_empty_lines(lines)
    if vim.tbl_isempty(lines) then
        return
    end

    config = vim.tbl_deep_extend("force", {
        border = "rounded",
        focusable = false,
    }, config or {})

    return vim.lsp.util.open_floating_preview(lines, "text", config)
end

local augroup = vim.api.nvim_create_augroup
local FranGroup = augroup('Fran', {})

local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup('HighlightYank', {})

function R(name)
    require("plenary.reload").reload_module(name)
end

vim.filetype.add({
    extension = {
        templ = 'templ',
    }
})

autocmd('TextYankPost', {
    group = yank_group,
    pattern = '*',
    callback = function()
        vim.highlight.on_yank({
            higroup = 'IncSearch',
            timeout = 40,
        })
    end,
})

autocmd('FileType', {
    group = FranGroup,
    pattern = { "markdown" },
    callback = function(args)
        pcall(vim.treesitter.stop, args.buf)
    end,
})

autocmd({"BufWritePre"}, {
    group = FranGroup,
    pattern = "*",
    command = [[%s/\s\+$//e]],
})

autocmd('LspAttach', {
    group = FranGroup,
    callback = function(e)
        local opts = { buffer = e.buf }
        vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
        vim.keymap.set("n", "K", hover_plain, opts)
        vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
        vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
        vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
        vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
        vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
        vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
        vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, opts)
        vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, opts)
    end
})

vim.g.netrw_browse_split = 0
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 25

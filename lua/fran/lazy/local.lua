return {
    {
        "franpfeiffer/vfp-lsp",
        ft = { "vfp", "foxpro" },
        config = function()
            require("vfp-lsp").setup()
        end,
    }
}
-- return {
--     {
--         dir = "/home/fran/work/fxp-lsp/editors/neovim",
--         ft = { "vfp", "foxpro" },
--         config = function()
--             vim.api.nvim_create_autocmd("FileType", {
--                 pattern = { "vfp", "foxpro" },
--                 callback = function()
--                     local client = vim.lsp.start({
--                         name = "vfp-lsp",
--                         cmd = { "/home/fran/work/fxp-lsp/target/release/vfp-lsp" },
--                         root_dir = vim.fn.getcwd(),
--                     })
--
--                     if client then
--                         local bufnr = vim.api.nvim_get_current_buf()
--                         local opts = { buffer = bufnr, silent = true }
--                         vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
--                         vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
--                         vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
--                         vim.keymap.set('i', '<C-Space>', vim.lsp.buf.completion, opts)
--                     end
--                 end,
--             })
--         end,
--     }
-- }

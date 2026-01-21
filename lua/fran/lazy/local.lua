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
--         dir = "/home/fran/work/vfp-lsp/editors/neovim",
--         ft = { "vfp", "foxpro" },
--         config = function()
--             require("vfp-lsp").setup({
--                 cmd = { "/home/fran/work/vfp-lsp/target/release/vfp-lsp" },
--                 auto_install = false,
--             })
--         end,
--     }
-- }

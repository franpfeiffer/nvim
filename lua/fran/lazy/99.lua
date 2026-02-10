return {
    {
        "ThePrimeagen/99",
        config = function()
            local home_tmp = vim.fn.expand("~/tmp")
            vim.fn.mkdir(home_tmp, "p")
            vim.env.TMPDIR = home_tmp

            local _99 = require("99")

            local cwd = vim.uv.cwd()
            local basename = vim.fs.basename(cwd)

            _99.setup({
                provider = _99.ClaudeCodeProvider,
                logger = {
                    level = _99.DEBUG,
                    path = "/tmp/" .. basename .. ".99.debug",
                    print_on_error = true,
                },
                completion = {
                    custom_rules = {},
                    files = {},
                    source = "cmp",
                },
                md_files = {
                    "AGENT.md",
                },
            })

            vim.keymap.set("v", "<leader>9v", function()
                _99.visual()
            end, { desc = "99: visual request" })

            vim.keymap.set("v", "<leader>9s", function()
                _99.stop_all_requests()
            end, { desc = "99: stop requests" })
        end,
    },
}

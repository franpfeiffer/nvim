-- teej-style "gui" features, terminal edition
-- brain rot: already in surfers.lua / ani.lua / cellular-automaton
-- ponytail: no remote sync/shared chat daemon, try jbyuki/instant.nvim if needed
return {
    { "nvzone/volt", lazy = true },

    -- right-click context menu
    {
        "nvzone/menu",
        lazy = true,
        init = function()
            vim.keymap.set({ "n", "v" }, "<RightMouse>", function()
                require("menu.utils").delete_old_menus()
                vim.cmd.exec('"normal! \\<RightMouse>"')
                require("menu").open("default", { mouse = true })
            end, { desc = "Context menu" })
            vim.keymap.set("n", "<C-t>", function()
                require("menu").open("default")
            end, { desc = "Context menu" })
        end,
    },

    -- live color picker / shade tweaker
    { "nvzone/minty", cmd = { "Shades", "Huefy" } },

    -- markdown rendered in-buffer, synced as you type
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = "markdown",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        opts = {},
    },

    -- visual LSP references/definitions peek
    {
        "dnlhc/glance.nvim",
        cmd = "Glance",
        keys = {
            { "gR", "<cmd>Glance references<cr>", desc = "Glance references" },
            { "gD", "<cmd>Glance definitions<cr>", desc = "Glance definitions" },
            { "gM", "<cmd>Glance implementations<cr>", desc = "Glance implementations" },
        },
    },

    -- linear (API key prompted on first use, stored in stdpath("data"), not in repo)
    {
        "rmanocha/linear-nvim",
        dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim", "stevearc/dressing.nvim" },
        keys = {
            { "<leader>li", function() require("linear-nvim").show_assigned_issues() end, desc = "Linear: my issues" },
            { "<leader>lc", function() require("linear-nvim").create_issue() end, mode = { "n", "v" }, desc = "Linear: create issue" },
            { "<leader>ld", function() require("linear-nvim").show_issue_details() end, desc = "Linear: issue details" },
        },
        config = function()
            require("linear-nvim").setup()
        end,
    },
}

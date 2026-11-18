return {
    {
        "franpfeiffer/ani.nvim",
        -- local development: dir = "/home/fran/personal/ani.nvim",
        cmd = { "Ani", "AniStop" },
        keys = {
            { "<leader>oa", "<cmd>Ani<cr>", desc = "Anime: search" },
            { "<leader>oc", "<cmd>Ani -c<cr>", desc = "Anime: continue" },
            { "<leader>os", "<cmd>AniStop<cr>", desc = "Anime: stop" },
        },
        opts = {
            menu = { position = "top-right" },
        },
    },
}

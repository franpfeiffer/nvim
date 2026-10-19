return {
    {
    "nvim-treesitter/nvim-treesitter",
    -- master is archived and breaks on nvim 0.12 (match[id] is now a node list)
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        -- ponytail: fixed list replaces auto_install, add langs here when needed
        require("nvim-treesitter").install({
            "vimdoc", "javascript", "typescript", "tsx", "c", "cpp", "lua", "rust",
            "jsdoc", "bash", "go", "gomod", "gosum", "python", "php", "ruby", "zig",
            "css", "html", "json", "yaml", "toml", "xml", "make", "dockerfile",
            "diff", "gitcommit", "git_config", "gitignore", "gitattributes",
            "hyprlang", "ini", "vim", "markdown", "templ",
        })

        local max_filesize = 100 * 1024 -- 100 KB
        vim.api.nvim_create_autocmd("FileType", {
            callback = function(ev)
                local ft = vim.bo[ev.buf].filetype
                if ft == "html" or ft == "markdown" then
                    return
                end

                local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(ev.buf))
                if ok and stats and stats.size > max_filesize then
                    vim.notify(
                        "File larger than 100KB treesitter disabled for performance",
                        vim.log.levels.WARN,
                        {title = "Treesitter"}
                    )
                    return
                end

                if pcall(vim.treesitter.start, ev.buf) then
                    vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                end
            end,
        })
    end
    },

    {
        "nvim-treesitter/nvim-treesitter-context",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        config = function()
            local disabled_filetypes = {
                markdown = true,
            }

            require'treesitter-context'.setup{
                enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
                multiwindow = false, -- Enable multiwindow support.
                max_lines = 1, -- How many lines the window should span. Values <= 0 mean no limit.
                min_window_height = 0, -- Minimum editor window height to enable context. Values <= 0 mean no limit.
                line_numbers = true,
                multiline_threshold = 20, -- Maximum number of lines to show for a single context
                trim_scope = 'outer', -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
                mode = 'cursor',  -- Line used to calculate context. Choices: 'cursor', 'topline'
                -- Separator between context and content. Should be a single character string, like '-'.
                -- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
                separator = nil,
                zindex = 20, -- The Z-index of the context window
                on_attach = function(buf)
                    return not disabled_filetypes[vim.bo[buf].filetype]
                end,
            }
        end
    }
}

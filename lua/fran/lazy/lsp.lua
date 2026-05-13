return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "stevearc/conform.nvim",
        "mason-org/mason.nvim",
        "mason-org/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "hrsh7th/nvim-cmp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "j-hui/fidget.nvim",
    },

    config = function()
        local cmp = require('cmp')
        local cmp_lsp = require("cmp_nvim_lsp")
        local capabilities = cmp_lsp.default_capabilities()

        -- Asegurar soporte para additionalTextEdits (auto-imports)
        capabilities.textDocument.completion.completionItem.resolveSupport = {
            properties = {
                "documentation",
                "detail",
                "additionalTextEdits",
            },
        }

        require("fidget").setup({})
        require("mason").setup()
        local servers = {
            "lua_ls",
            "rust_analyzer",
            "gopls",
            "vtsls",
            "tailwindcss",
        }

        require("mason-lspconfig").setup({
            ensure_installed = servers,
            automatic_enable = false,
        })

        for _, server in ipairs(servers) do
            vim.lsp.config(server, {
                capabilities = capabilities,
            })
        end

        vim.lsp.config("lua_ls", {
            capabilities = capabilities,
            settings = {
                Lua = {
                    diagnostics = {
                        globals = { "vim" },
                    },
                    format = {
                        enable = true,
                        defaultConfig = {
                            indent_style = "space",
                            indent_size = "2",
                        },
                    },
                },
            },
        })

        vim.lsp.config("tailwindcss", {
            capabilities = capabilities,
            filetypes = { "html", "css", "scss", "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte", "heex" },
        })

        vim.lsp.config("vtsls", {
            capabilities = capabilities,
            init_options = {
                preferences = {
                    includePackageJsonAutoImports = "on",
                    autoImportFileExcludePatterns = { "**/dist/**", "**/.next/**" },
                },
            },
            settings = {
                typescript = {
                    suggest = {
                        completeFunctionCalls = true,
                    },
                    updateImportsOnFileMove = { enabled = "always" },
                    inlayHints = {
                        parameterNames = { enabled = "all" },
                        parameterTypes = { enabled = true },
                        variableTypes = { enabled = true },
                        propertyDeclarationTypes = { enabled = true },
                        functionLikeReturnTypes = { enabled = true },
                    },
                },
                javascript = {
                    suggest = {
                        completeFunctionCalls = true,
                    },
                    updateImportsOnFileMove = { enabled = "always" },
                },
                vtsls = {
                    autoUseWorkspaceTsdk = true,
                    experimental = {
                        completion = {
                            enableServerSideFuzzyMatch = true,
                        },
                    },
                },
            },
        })

        vim.lsp.config("zls", {
            capabilities = capabilities,
            root_dir = function(bufnr)
                return vim.fs.root(bufnr, { ".git", "build.zig", "zls.json" })
            end,
            settings = {
                zls = {
                    enable_inlay_hints = true,
                    enable_snippets = true,
                    warn_style = true,
                },
            },
        })

        vim.g.zig_fmt_parse_errors = 0
        vim.g.zig_fmt_autosave = 0

        for _, server in ipairs(servers) do
            vim.lsp.enable(server)
        end

        local cmp_select = { behavior = cmp.SelectBehavior.Select }

        cmp.setup({
            snippet = {
                expand = function(args)
                    require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
                end,
            },
            mapping = cmp.mapping.preset.insert({
                ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
                ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
                ['<C-y>'] = cmp.mapping.confirm({ select = true }),
                ["<C-Space>"] = cmp.mapping.complete(),
            }),
            sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'luasnip' }, -- For luasnip users.
            }, {
                { name = 'buffer' },
            })
        })

        vim.diagnostic.config({
            virtual_text = true,
            -- update_in_insert = true,
            float = {
                focusable = false,
                style = "minimal",
                border = "rounded",
                source = "always",
                header = "",
                prefix = "",
            },
        })
    end
}

local api = vim.api

-- auto-reload files changed on disk (agents, git, etc.)
-- ponytail: 1s poll, swap to vim.uv.new_fs_event per buffer if lag bothers you
vim.o.autoread = true
vim.uv.new_timer():start(1000, 1000, vim.schedule_wrap(function()
    if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
        vim.cmd("silent! checktime")
    end
end))

-- floating markdown preview: separate buffer mirrored both ways with the real file,
-- only this buffer gets rendered (see render-markdown `ignore` in lazy/gui.lua)
-- <leader>mf opens, then jumps in/out; :w saves the real file; :q closes
local md = {}
local applying = false
local function mirror(from, to)
    api.nvim_buf_attach(from, false, {
        on_lines = function(_, _, _, first, last, new_last)
            if not api.nvim_buf_is_valid(to) then return true end
            if applying then return end
            local lines = api.nvim_buf_get_lines(from, first, new_last, false)
            vim.schedule(function()
                if not api.nvim_buf_is_valid(to) then return end
                applying = true
                pcall(api.nvim_buf_set_lines, to, first, last, false, lines)
                applying = false
            end)
        end,
    })
end
local function md_float(path)
    if md.win and api.nvim_win_is_valid(md.win) then
        if api.nvim_get_current_win() == md.win then
            api.nvim_set_current_win(md.prev)
        else
            md.prev = api.nvim_get_current_win()
            api.nvim_set_current_win(md.win)
        end
        return
    end
    if not path or path == "" then
        path = vim.bo.filetype == "markdown" and api.nvim_buf_get_name(0) or "README.md"
    end
    md.prev = api.nvim_get_current_win()
    local src = vim.fn.bufadd(path)
    vim.fn.bufload(src)
    vim.bo[src].buflisted = true

    local buf = api.nvim_create_buf(false, true)
    vim.b[buf].md_preview = true
    api.nvim_buf_set_lines(buf, 0, -1, false, api.nvim_buf_get_lines(src, 0, -1, false))
    api.nvim_buf_set_name(buf, "mdpreview://" .. path)
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].modified = false
    vim.bo[buf].filetype = "markdown"
    pcall(vim.treesitter.start, buf, "markdown") -- your FileType autocmd stops it; hiding links/backticks needs it
    api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            api.nvim_buf_call(src, function() vim.cmd("write") end)
            vim.bo[buf].modified = false
        end,
    })
    mirror(src, buf)
    mirror(buf, src)

    local line = api.nvim_win_get_buf(md.prev) == src and api.nvim_win_get_cursor(md.prev)[1] or 1
    local w, h = math.floor(vim.o.columns * 0.6), math.floor(vim.o.lines * 0.7)
    md.win = api.nvim_open_win(buf, true, {
        relative = "editor", width = w, height = h,
        row = math.floor((vim.o.lines - h) / 2), col = math.floor((vim.o.columns - w) / 2),
        border = "rounded", title = " " .. vim.fn.fnamemodify(path, ":t") .. " ", title_pos = "center",
    })
    vim.wo[md.win].wrap = true
    vim.wo[md.win].linebreak = true
    vim.wo[md.win].number = false
    vim.wo[md.win].relativenumber = false
    vim.wo[md.win].colorcolumn = ""
    api.nvim_win_set_cursor(md.win, { line, 0 })
end
api.nvim_create_user_command("MdFloat", function(o) md_float(o.args) end, { nargs = "?", complete = "file" })
vim.keymap.set("n", "<leader>mf", md_float, { desc = "Markdown float (open / jump)" })

-- reference arrows: connector in the right margin from cursor to every ref in this file
local ns = api.nvim_create_namespace("ref_arrows")
local function clear_arrows()
    for _, b in ipairs(api.nvim_list_bufs()) do api.nvim_buf_clear_namespace(b, ns, 0, -1) end
end
local function draw_arrows()
    local buf = api.nvim_get_current_buf()
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local client = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/references" })[1]
    if not client then return end
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    params.context = { includeDeclaration = true }
    local cur = api.nvim_win_get_cursor(0)[1] - 1
    client:request("textDocument/references", params, function(err, result)
        if err or not result or not api.nvim_buf_is_valid(buf) then return end
        api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        local uri, refs, first, last = vim.uri_from_bufnr(buf), {}, cur, cur
        for _, loc in ipairs(result) do
            if loc.uri == uri then
                local l = loc.range.start.line
                refs[l], first, last = true, math.min(first, l), math.max(last, l)
            end
        end
        if first == last then return end
        -- ponytail: margin sits after the longest line in range; off-screen if lines are wider than the window
        local col = 0
        for _, s in ipairs(api.nvim_buf_get_lines(buf, first, last + 1, false)) do
            col = math.max(col, vim.fn.strdisplaywidth(s))
        end
        for l = first, last do
            local bar = l == first and "╮" or l == last and "╯" or "│"
            local tip = l == cur and "●──" or refs[l] and "◀──" or "   "
            if tip ~= "   " and bar == "│" then bar = "┤" end
            api.nvim_buf_set_extmark(buf, ns, l, 0, {
                virt_text = { { tip .. bar, l == cur and "DiagnosticWarn" or "DiagnosticInfo" } },
                virt_text_win_col = col + 2,
            })
        end
    end, buf)
end
local arrows_group = api.nvim_create_augroup("RefArrows", {})
local arrows_on = false
api.nvim_create_user_command("RefArrows", function()
    arrows_on = not arrows_on
    api.nvim_clear_autocmds({ group = arrows_group })
    clear_arrows()
    if arrows_on then
        api.nvim_create_autocmd("CursorHold", { group = arrows_group, callback = draw_arrows })
        draw_arrows()
    end
end, {})
vim.keymap.set("n", "<leader>vra", "<cmd>RefArrows<cr>", { desc = "Toggle reference arrows" })

-- brainrot: real video in a floating mpv window that stays on its workspace (toggle)
-- video comes from subway-surfers.nvim's download
local rot
local function hypr_place(pid, prev, tries)
    vim.defer_fn(function()
        local ok, clients = pcall(vim.json.decode, vim.fn.system({ "hyprctl", "clients", "-j" }))
        if not (ok and vim.iter(clients):any(function(c) return c.pid == pid end)) then
            if tries > 0 then hypr_place(pid, prev, tries - 1) end
            return
        end
        local mon = vim.iter(vim.json.decode(vim.fn.system({ "hyprctl", "monitors", "-j" })))
            :find(function(m) return m.focused end)
        local mw, mh = mon.width / mon.scale, mon.height / mon.scale
        local w, h = math.floor(mw * 0.22), math.floor(mh * 0.45)
        local x, y = mon.x + math.floor(mw - w - 20), mon.y + 60
        local win = "pid:" .. pid
        vim.fn.system({ "hyprctl", "--batch", table.concat({
            "dispatch setfloating " .. win,
            ("dispatch resizewindowpixel exact %d %d,%s"):format(w, h, win),
            ("dispatch movewindowpixel exact %d %d,%s"):format(x, y, win),
            prev and ("dispatch focuswindow address:" .. prev) or "",
        }, " ; ") })
    end, 100)
end
api.nvim_create_user_command("Brainrot", function()
    if rot then
        rot:kill(15)
        rot = nil
        return
    end
    local file = vim.fn.glob(vim.fn.stdpath("data") .. "/subway-surfers.nvim/*.mp4", false, true)[1]
    if not file then
        return vim.notify("No video yet, run :SubwaySurfers download", vim.log.levels.WARN)
    end
    local prev
    if vim.env.HYPRLAND_INSTANCE_SIGNATURE then
        local ok, active = pcall(vim.json.decode, vim.fn.system({ "hyprctl", "activewindow", "-j" }))
        prev = ok and active.address or nil
    end
    rot = vim.system({
        "mpv", "--loop", "--no-audio", "--ontop", "--no-border", "--force-window=immediate",
        "--title=nvim-brainrot", "--geometry=22%x45%-20+60", file,
    }, {}, function() rot = nil end)
    -- Hyprland ignores --geometry for tiled windows, so float just this mpv window at runtime
    if vim.env.HYPRLAND_INSTANCE_SIGNATURE then hypr_place(rot.pid, prev, 30) end
end, {})
vim.keymap.set("n", "<leader>ob", "<cmd>Brainrot<cr>", { desc = "Brainrot video (toggle)" })

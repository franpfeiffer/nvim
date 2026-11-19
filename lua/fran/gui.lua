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

-- reference arrows: real curved lines drawn OVER the code from the symbol under the cursor
-- to every visible reference. svg -> png (magick) -> kitty graphics protocol (ghostty/kitty).
-- inside tmux the escapes go through passthrough, enabled for this pane only at runtime.
-- ponytail: cleared on any cursor move/scroll; assumes tmux status bar at the bottom.
local IMG_ID, CW, CH = 4242, 10, 22 -- fake cell px size; terminal scales image to the grid
local gen = 0

local function tty(seq)
    if vim.env.TMUX then seq = "\027Ptmux;" .. seq:gsub("\027", "\027\027") .. "\027\\" end
    api.nvim_ui_send(seq)
end

local function clear_arrows()
    gen = gen + 1
    tty("\027_Ga=d,d=i,i=" .. IMG_ID .. ",q=2\027\\")
end

local function show_png(png)
    local top, left = 0, 0
    if vim.env.TMUX then
        local out = vim.fn.system({ "tmux", "display", "-p", "-t", vim.env.TMUX_PANE or "", "#{pane_top} #{pane_left}" })
        top, left = out:match("(%d+) (%d+)")
        top, left = tonumber(top) or 0, tonumber(left) or 0
    end
    local data = vim.base64.encode(png)
    local seq = { ("\0277\027[%d;%dH"):format(top + 1, left + 1) }
    for i = 1, #data, 4096 do
        local chunk, more = data:sub(i, i + 4095), (i + 4096 <= #data) and 1 or 0
        local head = i == 1
            and ("a=T,f=100,q=2,C=1,i=%d,c=%d,r=%d,m=%d"):format(IMG_ID, vim.o.columns, vim.o.lines, more)
            or ("m=%d"):format(more)
        seq[#seq + 1] = "\027_G" .. head .. ";" .. chunk .. "\027\\"
    end
    seq[#seq + 1] = "\0278"
    tty(table.concat(seq))
end

local function draw_arrows()
    clear_arrows()
    local my_gen, buf, win = gen, api.nvim_get_current_buf(), api.nvim_get_current_win()
    local client = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/references" })[1]
    if not client then return end
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    params.context = { includeDeclaration = true }
    local r0, c0 = unpack(api.nvim_win_get_cursor(0))
    client:request("textDocument/references", params, function(err, result)
        if my_gen ~= gen or err or not result or not api.nvim_win_is_valid(win) then return end
        local uri, anchor, targets = vim.uri_from_bufnr(buf), nil, {}
        for _, loc in ipairs(result) do
            if loc.uri == uri then
                local s, e = loc.range.start, loc.range["end"]
                local l = api.nvim_buf_get_lines(buf, s.line, s.line + 1, false)[1] or ""
                local sb = vim.str_byteindex(l, client.offset_encoding, s.character, false)
                local eb = vim.str_byteindex(l, client.offset_encoding, e.character, false)
                local p = vim.fn.screenpos(win, s.line + 1, sb + 1)
                local width = vim.fn.strdisplaywidth(l:sub(sb + 1, eb))
                if s.line + 1 == r0 and sb <= c0 and c0 < eb then
                    anchor = p.row > 0 and { x = (p.col - 1 + width / 2) * CW, y = p.row * CH - 2 } or nil
                elseif p.row > 0 then
                    targets[#targets + 1] = { x = (p.col - 1 + width / 2) * CW, y = (p.row - 1) * CH + 2 }
                end
            end
        end
        if not anchor or #targets == 0 then return end

        local hl = api.nvim_get_hl(0, { name = "DiagnosticInfo", link = false })
        local color = hl.fg and ("#%06x"):format(hl.fg) or "#7fb4ca"
        local paths = {}
        for _, t in ipairs(targets) do
            local dx, dy = t.x - anchor.x, t.y - anchor.y
            local cx, cy = (anchor.x + t.x) / 2 - dy * 0.3, (anchor.y + t.y) / 2 + dx * 0.3
            paths[#paths + 1] = ('<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" marker-end="url(#a)"/>')
                :format(anchor.x, anchor.y, cx, cy, t.x, t.y)
        end
        local svg = table.concat({
            ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">'):format(vim.o.columns * CW, vim.o.lines * CH),
            ('<defs><marker id="a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">'
                .. '<path d="M0 0 L8 4 L0 8 z" fill="%s"/></marker></defs>'):format(color),
            ('<g fill="none" stroke="%s" stroke-width="1.6" stroke-linecap="round" opacity="0.9">'):format(color),
            table.concat(paths), "</g></svg>",
        })
        vim.system({ "magick", "-background", "none", "svg:-", "png:-" }, { stdin = svg, text = false }, function(res)
            vim.schedule(function()
                if my_gen == gen and res.code == 0 and #res.stdout > 0 then show_png(res.stdout) end
            end)
        end)
    end, buf)
end
local arrows_group = api.nvim_create_augroup("RefArrows", {})
local arrows_on = false
api.nvim_create_user_command("RefArrows", function()
    arrows_on = not arrows_on
    api.nvim_clear_autocmds({ group = arrows_group })
    clear_arrows()
    if arrows_on then
        if vim.env.TMUX then vim.fn.system({ "tmux", "set", "-p", "allow-passthrough", "on" }) end
        api.nvim_create_autocmd("CursorHold", { group = arrows_group, callback = draw_arrows })
        api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled", "BufLeave", "FocusLost", "VimLeavePre", "VimResized" },
            { group = arrows_group, callback = clear_arrows })
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

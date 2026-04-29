-- lua/org_progress.lua
-- Renders study.org progress in a floating window pinned to the top-right,
-- like an LSP diagnostic panel. Uses a normal unlisted scratch buffer so
-- orgmode can't interfere.

local M = {}

local ns      = vim.api.nvim_create_namespace("org_progress")
local timer   = nil
local last_data = nil
local float_win  = nil   -- the floating window handle
local float_buf  = nil   -- the scratch buffer we draw into

local cfg = {
  org_file   = vim.fn.expand("~/orgfiles/study.org"),
  bar_width  = 10,
  name_width = 18,
  interval   = 15,
  -- how many columns from the right edge to anchor the float
  right_pad  = 2,
  -- how many rows from the top to anchor the float
  top_pad    = 1,
  hl = {
    section  = "DiagnosticInfo",
    name     = "DiagnosticHint",
    bar_high = "DiagnosticOk",
    bar_mid  = "DiagnosticWarn",
    bar_low  = "Comment",
    pct_high = "DiagnosticOk",
    pct_mid  = "DiagnosticWarn",
    pct_low  = "Comment",
    muted    = "Comment",
    border   = "FloatBorder",
  },
}

-- ── embedded Python parser ────────────────────────────────────────────────────
local PARSER_PY = [[
import sys, re, json
DONE = {"DONE","FIXED","CLOSED","REJECTED"}
TODO = {"TODO","NEXT","WAITING","HOLD"}
PROG = {"PROGRESS"}
ALL  = DONE | TODO | PROG
def clean(s):
    s = re.sub(r':\S+:\s*$', '', s)
    s = re.sub(r'\[#[A-Z]\]\s*', '', s)
    s = re.sub(r'<[^>]+>', '', s)
    s = re.sub(r'\[\d+/\d+\]', '', s)
    return s.strip().rstrip(':').strip()
def parse(path):
    try:
        lines = open(path, encoding='utf-8', errors='replace').read().splitlines()
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return {}
    hre = re.compile(r'^(\*+)\s+(?:(\w+)\s+)?(.+)')
    sections, sec, sub = {}, None, None
    for line in lines:
        m = hre.match(line)
        if not m: continue
        lvl = len(m.group(1)); kw = (m.group(2) or '').upper(); title = clean(m.group(3))
        if not title: continue
        if lvl == 1 and kw not in ALL:
            sec = title; sub = None; sections.setdefault(sec, {}); continue
        if sec is None: continue
        if lvl == 2 and kw not in (TODO | DONE):
            sub = title or kw
            sections[sec].setdefault(sub, {"done":0,"todo":0,"in_progress":0}); continue
        if sub is None: continue
        b = sections[sec].setdefault(sub, {"done":0,"todo":0,"in_progress":0})
        if kw in DONE: b["done"] += 1
        elif kw in PROG: b["in_progress"] += 1
        elif kw in TODO: b["todo"] += 1
    return sections
print(json.dumps(parse(sys.argv[1])))
]]

-- ── helpers ───────────────────────────────────────────────────────────────────
local function pct(c)
  local total = c.done + c.todo + c.in_progress
  if total == 0 then return -1 end
  return (c.done + 0.5 * c.in_progress) / total * 100
end

local function make_bar(p, w)
  if p < 0 then return ("─"):rep(w) end
  local n = math.floor(p / 100 * w + 0.5)
  return ("█"):rep(n) .. ("░"):rep(w - n)
end

local function pick_hl(p, prefix)
  if p < 0   then return cfg.hl.bar_low end
  if p >= 70 then return cfg.hl[prefix .. "high"] end
  if p >= 30 then return cfg.hl[prefix .. "mid"] end
  return cfg.hl[prefix .. "low"]
end

-- ── build lines + highlights for the float buffer ────────────────────────────
-- returns:
--   lines  = list of plain strings (one per row)
--   hls    = list of {line, col_start, col_end, hl_group}
local function build_content(sections)
  local lines = {}
  local hls   = {}

  local function push(segments)
    local row  = #lines  -- 0-indexed
    local text = ""
    for _, seg in ipairs(segments) do
      local s, hl = seg[1], seg[2]
      if hl then
        table.insert(hls, { row, #text, #text + #s, hl })
      end
      text = text .. s
    end
    table.insert(lines, text)
  end

  local bw, nw = cfg.bar_width, cfg.name_width

  for section, subjects in pairs(sections) do
    push({ { "◆ " .. section:upper(), cfg.hl.section } })

    local any = false
    for name, c in pairs(subjects) do
      any = true
      local p    = pct(c)
      local b    = make_bar(p, bw)
      local pstr = p >= 0 and ("%3.0f%%"):format(p) or " n/a"
      local tot  = c.done + c.todo + c.in_progress
      local cnt  = ("%d/%d"):format(c.done, tot)
      local disp = name:sub(1, nw) .. (" "):rep(math.max(0, nw - #name:sub(1, nw)))

      push({
        { "  ",        nil                 },
        { disp .. " ", cfg.hl.name        },
        { b .. " ",    pick_hl(p, "bar_") },
        { pstr,        pick_hl(p, "pct_") },
        { " " .. cnt,  cfg.hl.muted       },
      })
    end

    if not any then
      push({ { "  (no tasks)", cfg.hl.muted } })
    end
    push({ { "", nil } })  -- blank spacer
  end

  return lines, hls
end

-- ── float window management ───────────────────────────────────────────────────
local function close_float()
  if float_win and vim.api.nvim_win_is_valid(float_win) then
    vim.api.nvim_win_close(float_win, true)
  end
  float_win = nil
end

local function ensure_float_buf()
  if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
    return float_buf
  end
  float_buf = vim.api.nvim_create_buf(false, true)  -- unlisted, scratch
  vim.bo[float_buf].bufhidden  = "hide"
  vim.bo[float_buf].buftype    = "nofile"
  vim.bo[float_buf].swapfile   = false
  vim.bo[float_buf].filetype   = ""
  return float_buf
end

local function open_or_update_float(lines, hls)
  local ui_w = vim.o.columns
  local ui_h = vim.o.lines

  -- compute float dimensions
  local content_w = 0
  for _, l in ipairs(lines) do
    content_w = math.max(content_w, vim.fn.strdisplaywidth(l))
  end
  local float_w = content_w + 2   -- +2 for border padding
  local float_h = math.min(#lines, ui_h - cfg.top_pad - 4)

  local col = ui_w - float_w - cfg.right_pad
  local row = cfg.top_pad

  local bufnr = ensure_float_buf()

  -- write lines into the scratch buffer
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false

  -- apply highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, h in ipairs(hls) do
    local lnum, cs, ce, hl = h[1], h[2], h[3], h[4]
    vim.api.nvim_buf_add_highlight(bufnr, ns, hl, lnum, cs, ce)
  end

  if float_win and vim.api.nvim_win_is_valid(float_win) then
    -- just reposition + resize existing window
    vim.api.nvim_win_set_config(float_win, {
      relative = "editor",
      row      = row,
      col      = col,
      width    = float_w,
      height   = float_h,
    })
  else
    -- open a new floating window
    float_win = vim.api.nvim_open_win(bufnr, false, {
      relative   = "editor",
      row        = row,
      col        = col,
      width      = float_w,
      height     = float_h,
      style      = "minimal",
      border     = "rounded",
      focusable  = false,
      zindex     = 10,
    })
    -- make it look passive — no cursor, correct bg
    vim.wo[float_win].wrap          = false
    vim.wo[float_win].cursorline    = false
    vim.wo[float_win].number        = false
    vim.wo[float_win].relativenumber = false
    vim.wo[float_win].signcolumn    = "no"
    vim.wo[float_win].winblend     = 10   -- slight transparency
  end
end

local function render()
  if not last_data then return end
  local lines, hls = build_content(last_data)
  open_or_update_float(lines, hls)
end

-- ── async parser ──────────────────────────────────────────────────────────────
local function refresh(org_file)
  local tmp = vim.fn.tempname() .. ".py"
  local f   = io.open(tmp, "w")
  if not f then return end
  f:write(PARSER_PY); f:close()

  local stdout = {}
  vim.fn.jobstart({ "python3", tmp, org_file }, {
    stdout_buffered = true,
    on_stdout = function(_, data) vim.list_extend(stdout, data) end,
    on_stderr = function(_, data)
      local msg = table.concat(data, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      if msg ~= "" then
        vim.notify("org_progress: " .. msg, vim.log.levels.WARN)
      end
    end,
    on_exit = function()
      vim.fn.delete(tmp)
      local raw = table.concat(stdout, "")
      local ok, data = pcall(vim.json.decode, raw)
      if ok and type(data) == "table" then
        last_data = data
        vim.schedule(render)
      else
        vim.notify("org_progress: parse failed — " .. raw, vim.log.levels.ERROR)
      end
    end,
  })
end

-- ── path matching ─────────────────────────────────────────────────────────────
local function is_study_org(bufname)
  if bufname == "" then return false end
  local target = vim.fn.resolve(vim.fn.expand(cfg.org_file))
  local actual = vim.fn.resolve(vim.fn.expand(bufname))
  return actual == target
end

-- ── setup ─────────────────────────────────────────────────────────────────────
function M.setup(user_cfg)
  cfg = vim.tbl_deep_extend("force", cfg, user_cfg or {})

  local group = vim.api.nvim_create_augroup("OrgProgress", { clear = true })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(ev)
      local bufname = vim.api.nvim_buf_get_name(ev.buf)
      if not is_study_org(bufname) then return end
      refresh(bufname)
    end,
  })

  -- hide float when leaving study.org
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function(ev)
      if is_study_org(vim.api.nvim_buf_get_name(ev.buf)) then
        close_float()
      end
    end,
  })

  -- re-render on save
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(ev)
      if is_study_org(vim.api.nvim_buf_get_name(ev.buf)) then
        refresh(vim.api.nvim_buf_get_name(ev.buf))
      end
    end,
  })

  -- reposition on resize
  vim.api.nvim_create_autocmd("VimResized", {
    group    = group,
    callback = render,
  })

  -- background re-parse
  if timer then timer:stop() end
  timer = vim.uv.new_timer()
  timer:start(cfg.interval * 1000, cfg.interval * 1000, vim.schedule_wrap(function()
    -- only refresh if study.org is currently visible
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf  = vim.api.nvim_win_get_buf(win)
      local name = vim.api.nvim_buf_get_name(buf)
      if is_study_org(name) then
        refresh(name)
        break
      end
    end
  end))
end

return M

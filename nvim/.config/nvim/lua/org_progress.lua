-- lua/org_progress.lua
-- Renders org progress in a floating window pinned to the top-right,
-- like an LSP diagnostic panel. Works for *any* org file in the current
-- buffer. Each top-level heading gets a main progress bar; each of its
-- branches (sub-headings) gets its own progress bar, drawn as a tree.
-- Uses a normal unlisted scratch buffer so orgmode can't interfere.

local M = {}

local ns      = vim.api.nvim_create_namespace("org_progress")
local timer   = nil
local last_data = nil
local float_win  = nil   -- the floating window handle
local float_buf  = nil   -- the scratch buffer we draw into
local visible    = true  -- toggled by M.toggle()

local cfg = {
  bar_width  = 10,
  name_width = 18,
  interval   = 15,
  -- "hours": progress = completed :Effort: hours / total :Effort: hours
  --          (falls back to counting tasks/checkboxes where there is no Effort)
  -- "count": progress = done tasks + checkboxes / total
  mode       = "hours",
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
-- Emits an ordered list of top-level items. Each item aggregates its
-- descendants and carries a list of branches (its level-2 children) that each
-- aggregate their own descendants.
--   [ { "name", done, todo, in_progress, eff_done, eff_total, clocked,
--       branches: [ { same fields }, ... ] }, ... ]
--
-- Hours (minutes in the JSON) come from :Effort: and CLOCK: lines:
--   * a heading's Effort counts only if no descendant has its own Effort
--     (so a parent estimate isn't double-counted with its children's)
--   * DONE-type keyword          -> the whole Effort is done
--   * REJECTED                   -> left out entirely
--   * otherwise                  -> max(checkbox fraction × Effort,
--                                       clocked time incl. sub-headings),
--                                   capped at Effort
-- done/todo/in_progress keep the old keyword+checkbox counts and are used
-- as a fallback when a node has no Effort at all.
local PARSER_PY = [==[
import sys, re, json
from datetime import datetime
DONE = {"DONE","FIXED","CLOSED"}
SKIP = {"REJECTED"}
PROG = {"PROGRESS","DOING","NEXT"}
TODO = {"TODO","WAITING","HOLD"}
ALL  = DONE | SKIP | PROG | TODO
def clean(s):
    s = re.sub(r':\S+:\s*$', '', s)
    s = re.sub(r'\[#[A-Z]\]\s*', '', s)
    s = re.sub(r'<[^>]+>', '', s)
    s = re.sub(r'\[\d*/\d*\]', '', s)
    s = re.sub(r'\[\d*%\]', '', s)
    return s.strip().rstrip(':').strip()
def effort_minutes(v):
    v = v.strip().lower()
    m = re.fullmatch(r'(\d+):(\d{1,2})', v)
    if m: return int(m.group(1)) * 60 + int(m.group(2))
    total, found = 0.0, False
    for num, unit in re.findall(r'(\d+(?:\.\d+)?)\s*(d|h|min|m)\b', v):
        found = True
        total += float(num) * {"d": 1440, "h": 60, "min": 1, "m": 1}[unit]
    if found: return int(total)
    try: return int(float(v))   # bare number = minutes (org default)
    except ValueError: return 0
TS = r'\[(\d{4}-\d{2}-\d{2})[^\]\d]*(\d{1,2}:\d{2})\]'
def parse_ts(d, t):
    return datetime.strptime(d + " " + t, "%Y-%m-%d %H:%M")
def new(name):
    return {"name": name, "done": 0, "todo": 0, "in_progress": 0,
            "eff_done": 0, "eff_total": 0, "clocked": 0, "branches": []}
def add_kw(node, kw):
    if kw in DONE or kw in SKIP: node["done"] += 1
    elif kw in PROG: node["in_progress"] += 1
    elif kw in TODO: node["todo"] += 1
def add_cb(node, ch):
    if ch in ('x', 'X'): node["done"] += 1
    elif ch == '-': node["in_progress"] += 1
    else: node["todo"] += 1
def parse(path):
    try:
        lines = open(path, encoding='utf-8', errors='replace').read().splitlines()
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return []
    hre   = re.compile(r'^(\*+)\s+(.*)$')
    cbre  = re.compile(r'^\s*(?:[-+]|\d+[.)])\s+\[([ xX-])\]')
    effre = re.compile(r'^\s*:Effort:\s*(.+?)\s*$', re.I)
    clkre = re.compile(r'^\s*CLOCK:\s*' + TS + r'(?:--' + TS + r')?')
    now = datetime.now()
    tops, heads = [], []      # heads: every heading under a top
    cur_top = cur_branch = cur = None
    for line in lines:
        m = hre.match(line)
        if not m:
            if cur_top is None: continue
            cm = cbre.match(line)
            if cm:
                ch = cm.group(1)
                add_cb(cur_top, ch)
                if cur_branch is not None: add_cb(cur_branch, ch)
                cur["cb_n"] += 1
                cur["cb_done"] += 1 if ch in 'xX' else (0.5 if ch == '-' else 0)
                continue
            em = effre.match(line)
            if em:
                cur["effort"] = effort_minutes(em.group(1))
                continue
            km = clkre.match(line)
            if km:
                start = parse_ts(km.group(1), km.group(2))
                end = parse_ts(km.group(3), km.group(4)) if km.group(3) else now
                cur["clocked"] += max(0, int((end - start).total_seconds() // 60))
            continue
        lvl = len(m.group(1))
        rest = m.group(2)
        kw = ''
        parts = rest.split(None, 1)
        if parts and parts[0].upper() in ALL:
            kw = parts[0].upper()
            rest = parts[1] if len(parts) > 1 else ''
            # "DONE REJECTED ..." -> treat as rejected
            p2 = rest.split(None, 1)
            if p2 and p2[0].upper() in SKIP:
                kw = p2[0].upper()
                rest = p2[1] if len(p2) > 1 else ''
        title = clean(rest)
        if lvl == 1:
            cur_top = new(title or kw)
            tops.append(cur_top)
            cur_branch = None
        elif cur_top is None:
            continue
        elif lvl == 2:
            cur_branch = new(title or kw)
            cur_top["branches"].append(cur_branch)
        add_kw(cur_top, kw)
        if lvl >= 2 and cur_branch is not None: add_kw(cur_branch, kw)
        cur = {"lvl": lvl, "kw": kw, "effort": 0, "clocked": 0,
               "cb_n": 0, "cb_done": 0, "top": cur_top,
               "branch": cur_branch if lvl >= 2 else None, "desc_eff": False}
        heads.append(cur)
    # mark headings that have a descendant with its own Effort, and roll
    # clocked time up the tree (sub_clk = own + all descendants)
    stack = []
    for h in heads:
        while stack and stack[-1]["lvl"] >= h["lvl"]: stack.pop()
        h["sub_clk"] = h["clocked"]
        for a in stack:
            a["sub_clk"] += h["clocked"]
            if h["effort"]: a["desc_eff"] = True
        stack.append(h)
    for h in heads:
        targets = [h["top"]] + ([h["branch"]] if h["branch"] is not None else [])
        for t in targets: t["clocked"] += h["clocked"]
        e = h["effort"]
        if not e or h["desc_eff"] or h["kw"] in SKIP: continue
        if h["kw"] in DONE:
            d = e
        else:
            frac = h["cb_done"] / h["cb_n"] if h["cb_n"] else 0
            d = min(e, max(frac * e, h["sub_clk"]))
        for t in targets:
            t["eff_total"] += e
            t["eff_done"]  += d
    return tops
print(json.dumps(parse(sys.argv[1])))
]==]

-- ── helpers ───────────────────────────────────────────────────────────────────
local function uses_hours(c)
  return cfg.mode == "hours" and (c.eff_total or 0) > 0
end

local function pct(c)
  if uses_hours(c) then
    return c.eff_done / c.eff_total * 100
  end
  local total = c.done + c.todo + c.in_progress
  if total == 0 then return -1 end
  return (c.done + 0.5 * c.in_progress) / total * 100
end

-- minutes -> "12.5" style hours
local function hrs(min)
  local h = min / 60
  if h == math.floor(h) then return ("%d"):format(h) end
  return ("%.1f"):format(h)
end

local function count_str(c)
  if uses_hours(c) then
    return ("%s/%sh"):format(hrs(c.eff_done), hrs(c.eff_total))
  end
  return ("%d/%d"):format(c.done, c.done + c.todo + c.in_progress)
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

-- truncate/pad a name to a fixed display width
local function fit(name, w)
  local s = name:sub(1, w)
  return s .. (" "):rep(math.max(0, w - #s))
end

-- ── build lines + highlights for the float buffer ────────────────────────────
-- returns:
--   lines  = list of plain strings (one per row)
--   hls    = list of {line, col_start, col_end, hl_group}
local function build_content(tops)
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

  local function bar_row(prefix_seg, name, c)
    local p    = pct(c)
    local b    = make_bar(p, cfg.bar_width)
    local pstr = p >= 0 and ("%3.0f%%"):format(p) or " n/a"
    local cnt  = count_str(c)
    push({
      prefix_seg,
      { fit(name, cfg.name_width) .. " ", cfg.hl.name        },
      { b .. " ",                         pick_hl(p, "bar_") },
      { pstr,                             pick_hl(p, "pct_") },
      { " " .. cnt,                       cfg.hl.muted       },
    })
  end

  if #tops == 0 then
    push({ { "  (no headings)", cfg.hl.muted } })
    return lines, hls
  end

  for _, top in ipairs(tops) do
    -- top item header + its main aggregate progress bar
    push({ { "◆ " .. top.name:upper(), cfg.hl.section } })
    bar_row({ "  ", nil }, "total", top)

    for i, br in ipairs(top.branches) do
      local tree = (i == #top.branches) and "└─ " or "├─ "
      bar_row({ "  " .. tree, cfg.hl.muted }, br.name, br)
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
  if not visible or not last_data then return end
  local lines, hls = build_content(last_data)
  open_or_update_float(lines, hls)
end

-- ── async parser ──────────────────────────────────────────────────────────────
local function refresh(org_file)
  if not org_file or org_file == "" then return end
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

-- ── org file detection ──────────────────────────────────────────────────────
local function is_org_buf(buf)
  buf = buf or 0
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if vim.bo[buf].filetype == "org" then return true end
  local name = vim.api.nvim_buf_get_name(buf)
  return name:match("%.org$") ~= nil
end

-- ── toggle ────────────────────────────────────────────────────────────────────
function M.toggle()
  visible = not visible
  if not visible then
    close_float()
  elseif is_org_buf(0) then
    refresh(vim.api.nvim_buf_get_name(0))
  end
end

-- ── setup ─────────────────────────────────────────────────────────────────────
function M.setup(user_cfg)
  cfg = vim.tbl_deep_extend("force", cfg, user_cfg or {})

  local group = vim.api.nvim_create_augroup("OrgProgress", { clear = true })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(ev)
      if not is_org_buf(ev.buf) then return end
      refresh(vim.api.nvim_buf_get_name(ev.buf))
    end,
  })

  -- hide float when leaving an org file
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function(ev)
      if is_org_buf(ev.buf) then
        close_float()
      end
    end,
  })

  -- re-render on save
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(ev)
      if is_org_buf(ev.buf) then
        refresh(vim.api.nvim_buf_get_name(ev.buf))
      end
    end,
  })

  -- reposition on resize
  vim.api.nvim_create_autocmd("VimResized", {
    group    = group,
    callback = render,
  })

  -- background re-parse of the currently visible org file
  if timer then timer:stop() end
  timer = vim.uv.new_timer()
  timer:start(cfg.interval * 1000, cfg.interval * 1000, vim.schedule_wrap(function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if is_org_buf(buf) then
        refresh(vim.api.nvim_buf_get_name(buf))
        break
      end
    end
  end))
end

return M

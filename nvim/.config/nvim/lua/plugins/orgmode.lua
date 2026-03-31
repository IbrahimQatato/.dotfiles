return {
  "nvim-orgmode/orgmode",
  event = "VeryLazy",
  dependencies = {
    "nvim-orgmode/org-bullets.nvim",
  },
  config = function()
    require("orgmode").setup {
      org_agenda_files = "~/orgfiles/**",
      org_default_notes_file = "~/orgfiles/refile.org",
      org_capture_templates = {
        r = {
          description = "Repo",
          template = "* [[%x][%(return string.match('%x', '([^/]+)$'))]]%?",
          target = "~/orgfiles/repos.org",
        },
      },
      mappings = {
        org = {
          -- org_toggle_checkbox = "<C-Space>",
        },
      },
      -- org_agenda_use_time_grid = true,
      -- org_agenda_time_grid = {
      --   enabled = true,
      --   -- which conditions must be true to show the grid
      --   -- options: today, daily, weekly, require-timed
      --   display = { "weekly" }, -- change to {'daily'} to show grid on ALL days, not just today
      --   -- list of times to show (24h format integers)
      --   times = { 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000 },
      --   time_separator = "......",
      --   time_label = "",
      -- },
      -- org_agenda_span = "week", -- OR set to a number like 3 to see today + 2 days
      -- org_agenda_start_on_weekday = false, -- Starts the 'week' view on Today
    }
    -- Experimental LSP support
    vim.lsp.enable "org"
    require("org-bullets").setup {
      symbols = {
        checkboxes = {
          done = { "✓", "@org.checkbox.checked" }, -- use checkbox color, not keyword color
          half = { "", "@org.checkbox.halfchecked" },
          todo = { "˟", "@org.checkbox" },
        },
      },
    }
    -- for brighter Done marks
    -- vim.api.nvim_create_autocmd("ColorScheme", {
    --   pattern = "*",
    --   callback = function()
    --     vim.api.nvim_set_hl(0, "@org.keyword.done", { link = "DiagnosticOk" })
    --   end,
    -- })
  end,
}

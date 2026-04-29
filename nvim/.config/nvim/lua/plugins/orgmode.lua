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
      org_todo_keywords = { "TODO(t)", "DOING(p)", "|", "DONE(d)", "REJECTED(r)" },
      org_todo_keyword_faces = {
        PROGRESS = "foreground orange",
        DONE = "foreground green",
        -- PROGRESS = {link = "@comment.todo"},
        -- PROGRESS = ":foreground " .. get_hl_color "@comment.todo" .. " :weight bold",
        -- PROGRESS = ":foreground #00afff :weight bold",
      },
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
          org_cycle = "<M-j>",
          org_global_cycle = "<M-k>",
        },
      },
      -- org_agenda_use_time_grid = true,
      org_agenda_span = "day", -- OR set to a number like 3 to see today + 2 days
      org_agenda_start_on_weekday = false, -- Starts the 'week' view on Today
      --
    }

    -- vim.api.nvim_create_autocmd("ColorScheme", {
    --   pattern = "*",
    --   callback = function()
    --     vim.api.nvim_set_hl(0, "@org.agenda.scheduled", { link = "@comment.warning" })
    --   end,
    -- })
    vim.api.nvim_set_hl(0, "@org.agenda.scheduled", { link = "Normal" })
    -- Experimental LSP support
    vim.lsp.enable "org"
    require("org-bullets").setup {
      symbols = {
        checkboxes = {
          done = { "✓", "@org.checkbox.checked" }, -- use checkbox color, not keyword color
          half = { "-", "@org.checkbox.halfchecked" },
          todo = { "˟", "@org.checkbox" },
        },
      },
    }
  end,
}

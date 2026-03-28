return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },
  {
    "lervag/vimtex",
    lazy = false, -- we don't want to lazy load VimTeX
    -- tag = "v2.15", -- uncomment to pin to a specific release
    init = function()
      -- VimTeX configuration goes here, e.g.
      -- vim.g.vimtex_view_method = "zathura"
      vim.opt.conceallevel = 1
      vim.g.tex_conceal = "abdmgosf"
    end,
  },
  {
    "sirver/ultisnips",
    -- lazy = false,     -- we don't want to lazy load VimTeX
    init = function()
      -- vim.g.python3_host_prog = '/usr/bin/python'
      vim.g.UltiSnipsEditSplit = "vertical"
      -- vim.g.UltiSnipsSnippetDirectories = { "~/.config/nvim/UltiSnips" }

      -- vim.g.UltiSnipsSnippetDirectories = '/home/ibra/.config/nvim/UltiSnips'
    end,
    ft = { "tex" }, -- specify the file types for lazy loading
  },
  {
    "williamboman/mason.nvim",
    opts = function(_, conf)
      return conf
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "vim",
        "lua",
        "vimdoc",
        "html",
        "css",
      },
    },
  },
  -- Override LuaSnip config to include custom snippets
  {
    "L3MON4D3/LuaSnip",
    dependencies = { "rafamadriz/friendly-snippets" },
    config = function(_, opts)
      -- Merge default options with your custom paths
      local new_opts = vim.tbl_deep_extend("force", opts, {
        loaders = {
          from_lua = {
            require("luasnip.loaders.from_lua").lazy_load {
              paths = { "~/.config/nvim/lua/custom/snippets" },
            },
          },
        },
      })

      -- IMPORTANT: Load friendly-snippets explicitly
      require("luasnip.loaders.from_vscode").lazy_load()

      -- Setup with merged options
      require("luasnip").setup(new_opts)
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    opts = function()
      local cmp = require "cmp"
      local conf = require "nvchad.configs.cmp"

      local mymappings = {
        ["<A-k>"] = cmp.mapping.select_prev_item(),
        ["<A-j>"] = cmp.mapping.select_next_item(),
      }
      conf.mapping = vim.tbl_deep_extend("force", conf.mapping, mymappings)
      conf.mapping["<Tab>"] = nil
      conf.mapping["<S-Tab>"] = nil
      cmp.setup(conf)
      -- vim.print(conf.mapping)
      -- return conf
    end,
  },
  {
    "karb94/neoscroll.nvim",
    -- lazy = false,
    -- event = "WinScrolled",
    event = "VeryLazy", -- Loads slightly after startup, won't slow down opening files
    config = function()
      require("neoscroll").setup {
        mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "zt", "zz", "zb" },
        hide_cursor = true,
        stop_eof = true,
        respect_scrolloff = false,
        cursor_scrolls_alone = true,
        easing = "quadratic",
      }
    end,
  },
  {
    "mfussenegger/nvim-dap",
    ft = "python",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "rcarriga/nvim-dap-ui",
      "mfussenegger/nvim-dap-python",
      "theHamsta/nvim-dap-virtual-text",
    },
    opts = {
      ensure_installed = { "debugpy" }, -- Add more here, like "cppdbg" for C++
    },
    config = function()
      local dap = require "dap"
      local dapui = require "dapui"
      local dap_python = require "dap-python"

      require("dapui").setup {}
      require("nvim-dap-virtual-text").setup {
        commented = true, -- Show virtual text alongside comment
      }

      local mason_path = vim.fn.stdpath "data" .. "/mason/packages/debugpy/venv/bin/python"
      dap_python.setup(mason_path)
      -- dap_python.setup "python3"

      -- Override the default python configuration
      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch file (Dynamic)",
          program = "${file}",
          -- Best Practice: Use the currently active venv if it exists,
          -- otherwise fall back to system python
          -- pythonPath = function()
          --   local venv_path = os.getenv "VIRTUAL_ENV"
          --   if venv_path then
          --     return venv_path .. "/bin/python"
          --   end
          --   return "/usr/bin/python3"
          -- end,
          console = "internalConsole",
        },
      }

      vim.fn.sign_define("DapBreakpoint", {
        text = "",
        texthl = "DiagnosticSignError",
        linehl = "",
        numhl = "",
      })

      vim.fn.sign_define("DapBreakpointRejected", {
        text = "", -- or "❌"
        texthl = "DiagnosticSignError",
        linehl = "",
        numhl = "",
      })

      vim.fn.sign_define("DapStopped", {
        text = "", -- or "→"
        texthl = "DiagnosticSignWarn",
        linehl = "Visual",
        numhl = "DiagnosticSignWarn",
      })

      -- Automatically open/close DAP UI
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end

      -- Toggle breakpoint
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint", silent = true })

      -- Continue / Start
      vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Debug: Start/Continue", silent = true })

      -- Step Over
      vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "Debug: Step Over", silent = true })

      -- Step Into
      vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Debug: Step Into", silent = true })

      -- Step Out
      vim.keymap.set("n", "<leader>dO", dap.step_out, { desc = "Debug: Step Out", silent = true })

      -- Keymap to terminate debugging
      vim.keymap.set("n", "<leader>dq", require("dap").terminate, { desc = "Debug: Quit", silent = true })

      -- Toggle DAP UI
      vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug: Toggle UI", silent = true })
    end,
  },
  -- cppman
  -- {
  --   "madskjeldgaard/cppman.nvim",
  --   dependencies = {
  --     { "MunifTanjim/nui.nvim" },
  --   },
  --   ft="cpp",
  --   config = function()
  --     local cppman = require "cppman"
  --     cppman.setup()
  --
  --     -- Make a keymap to open the word under cursor in CPPman
  --     vim.keymap.set("n", "<leader>ci", function()
  --       cppman.open_cppman_for(vim.fn.expand "<cword>")
  --     end, { desc = "CPPMan: Search word under cursor" })
  --
  --     -- Open search box
  --     vim.keymap.set("n", "<leader>cc", function()
  --       cppman.input()
  --     end, { desc = "CPPMan: Open search box" })
  --   end,
  -- },
  --which to use?
  -- {
  --   "hrsh7th/nvim-cmp",
  --    opts = function(_, opts)
  --     local cmp = require("cmp")
  --     opts.mapping = cmp.mapping({
  --       ["<KEY>"] = cmp.mapping.confirm({ select = false/true }),
  --       ["<KEY>"] = cmp.mapping.abort(),
  --       ["<KEY>"] = cmp.mapping.select_next_item(),
  --       ["<KEY>"] = cmp.mapping.select_prev_item(),
  --       ["<KEY>"] = cmp.mapping.scroll_docs(-4),
  --       ["<KEY>"] = cmp.mapping.scroll_docs(4),
  --     })
  --  end,
  -- }
}

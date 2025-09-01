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

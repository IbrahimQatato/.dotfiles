-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

local lspconfig = vim.lsp.config
local util = require "lspconfig.util"

-- EXAMPLE
local servers = { "html", "cssls", "clangd", "pylsp", "prolog_ls", "hls" }
local nvlsp = require "nvchad.configs.lspconfig"

-- lsps with default config
-- for _, lsp in ipairs(servers) do
--   lspconfig[lsp].setup {
--     on_attach = nvlsp.on_attach,
--     on_init = nvlsp.on_init,
--     capabilities = nvlsp.capabilities,
--   }
-- end


-- configuring single server, example: typescript
-- lspconfig.ts_ls.setup {
--   on_attach = nvlsp.on_attach,
--   on_init = nvlsp.on_init,
--   capabilities = nvlsp.capabilities,
-- }

lspconfig.clangd = {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
  init_options = {
    fallbackFlags = { "--std=c++20" },
  },
}

lspconfig.pylsp = {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
  settings = {
    pylsp = {
      plugins = {
        pycodestyle = {
          ignore = { "W605", "E501" },
          maxLineLength = 100,
        },
      },
    },
  },
}

lspconfig.prolog_ls = {
  -- If you’re using the NvChad pattern, adapt accordingly
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
  cmd = {
    "/usr/bin/swipl",
    "-g",
    "use_module('/home/ibra/.local/share/prolog/lsp_server/prolog/lsp_server.pl').",
    "-g",
    "use_module(library(clpfd)).",
    "-g",
    "lsp_server:main",
    "-t",
    "halt",
    "--",
    "stdio",
  },
  filetypes = { "prolog" },

  -- Add this:
  root_dir = function(fname)
    -- 1) Try .git
    local git_root = util.find_git_ancestor(fname)
    if git_root then
      return git_root
    end
    -- 2) Fallback to the file’s directory
    return util.path.dirname(fname)
  end,
}

vim.lsp.enable(servers)

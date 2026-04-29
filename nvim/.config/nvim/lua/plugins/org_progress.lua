-- lua/plugins/org_progress.lua
return {
  {
    dir  = vim.fn.stdpath("config"),
    name = "org-progress",

    -- lazy=false so setup() runs at startup and the BufEnter autocmd is
    -- registered before study.org is opened. The module is tiny pure Lua
    -- so startup cost is negligible.
    lazy = false,

    config = function()
      require("org_progress").setup({
        org_file   = vim.fn.expand("~/orgfiles/study.org"),
        bar_width  = 10,
        name_width = 18,
        interval   = 15,
      })
    end,
  },
}

vim.notify("autocmds.lua loaded")
vim.api.nvim_create_autocmd("FileType", {
  pattern = "man",
  callback = function()
    require("base46").load_all_highlights()
  end,
})

require "nvchad.options"

-- add yours here!

-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!

local enable_providers = {
      "python3_provider",
      "node_provider",
      -- and so on
    }
    
    for _, plugin in pairs(enable_providers) do
      vim.g["loaded_" .. plugin] = nil
      vim.cmd("runtime " .. plugin)
    end


-- Set local options
vim.opt.spell = true
vim.opt.spelllang = { 'en_gb' }

vim.api.nvim_create_autocmd("FileType", {
  pattern = "jsonc",
  callback = function()
    vim.bo.commentstring = "// %s"
  end
})

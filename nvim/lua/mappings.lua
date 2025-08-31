require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

-- Set key mapping in insert mode
vim.api.nvim_set_keymap("i", "<C-l>", "<C-g>u<Esc>[s1z=`]a<C-g>u", { noremap = true, silent = true })

-- set code action
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP Code Action" })

map("n", "<leader>th", function ()
  require("nvchad.themes").open{ style = "compact"}
end, {})

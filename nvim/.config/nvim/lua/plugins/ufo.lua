-- return {
--   "kevinhwang91/nvim-ufo",
--   event = "VeryLazy",
--   dependencies = "kevinhwang91/promise-async",
--   config = function()
--     require("ufo").setup()
--   end,
-- }
return {
  "kevinhwang91/nvim-ufo",
  dependencies = "kevinhwang91/promise-async",
  event = "BufReadPost",
  init = function()
    -- These must be set BEFORE ufo loads
    vim.o.foldlevel = 99
    vim.o.foldlevelstart = 99
    vim.o.foldenable = true
    -- vim.o.foldcolumn = "1"
  end,
  config = function()
    local ufo = require("ufo")

    ufo.setup({
      -- File opens with all folds open
      open_fold_hl_timeout = 0,

      provider_selector = function(bufnr, filetype, buftype)
        return { "lsp" }
      end,

      fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = ("  ↙ %d lines"):format(endLnum - lnum)
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0
        for _, chunk in ipairs(virtText) do
          local chunkText = chunk[1]
          local chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
          else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            table.insert(newVirtText, { chunkText, chunk[2] })
            chunkWidth = vim.fn.strdisplaywidth(chunkText)
            if curWidth + chunkWidth < targetWidth then
              suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
            end
            break
          end
          curWidth = curWidth + chunkWidth
        end
        table.insert(newVirtText, { suffix, "MoreMsg" })
        return newVirtText
      end,
    })

    -- Keymaps
    vim.keymap.set("n", "zR", ufo.openAllFolds,          { desc = "Open all folds" })
    vim.keymap.set("n", "zM", ufo.closeAllFolds,         { desc = "Close all folds" })
    vim.keymap.set("n", "zr", ufo.openFoldsExceptKinds,  { desc = "Open folds except kinds" })
    vim.keymap.set("n", "zm", ufo.closeFoldsWith,        { desc = "Close folds with level" })
    vim.keymap.set("n", "K", function()
      local winid = ufo.peekFoldedLinesUnderCursor()
      if not winid then vim.lsp.buf.hover() end
    end, { desc = "Peek fold / LSP hover" })

    -- Save and restore folds between sessions
    local save_fold = vim.api.nvim_create_augroup("SaveFold", { clear = true })
    vim.api.nvim_create_autocmd("BufWinLeave", {
      group = save_fold,
      pattern = "*.*",        -- only real files, not unnamed buffers
      command = "silent! mkview",
    })
    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = save_fold,
      pattern = "*.*",
      command = "silent! loadview",
    })
  end,
}

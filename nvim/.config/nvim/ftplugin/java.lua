local ok, jdtls = pcall(require, "jdtls")
if not ok then
  return
end

local nvlsp = require "nvchad.configs.lspconfig"
local mason = vim.fn.stdpath "data" .. "/mason"

-- Project root: build files first, fall back to the file's own directory (single-file practice)
local root_dir = vim.fs.root(0, { "gradlew", "mvnw", "pom.xml", "build.gradle", "build.gradle.kts", ".git" })
  or vim.fn.expand "%:p:h"

-- jdtls needs a separate data dir per project
local workspace = vim.fn.stdpath "cache"
  .. "/jdtls/"
  .. vim.fn.fnamemodify(root_dir, ":t")
  .. "-"
  .. vim.fn.sha256(root_dir):sub(1, 8)

-- Debug + test runner extensions (installed via Mason)
local bundles = vim.fn.glob(mason .. "/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar", true, true)
for _, jar in ipairs(vim.fn.glob(mason .. "/packages/java-test/extension/server/*.jar", true, true)) do
  local name = vim.fn.fnamemodify(jar, ":t")
  if name ~= "com.microsoft.java.test.runner-jar-with-dependencies.jar" and name ~= "jacocoagent.jar" then
    table.insert(bundles, jar)
  end
end

jdtls.start_or_attach {
  cmd = { mason .. "/bin/jdtls", "-data", workspace },
  root_dir = root_dir,
  capabilities = nvlsp.capabilities,
  on_init = nvlsp.on_init,
  init_options = { bundles = bundles },
  settings = {
    java = {
      signatureHelp = { enabled = true },
      inlayHints = { parameterNames = { enabled = "all" } },
    },
  },
  on_attach = function(client, bufnr)
    nvlsp.on_attach(client, bufnr)
    jdtls.setup_dap { hotcodereplace = "auto" }

    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = "Java: " .. desc })
    end
    map("n", "<leader>jo", jdtls.organize_imports, "Organize imports")
    map({ "n", "v" }, "<leader>jv", jdtls.extract_variable, "Extract variable")
    map({ "n", "v" }, "<leader>jc", jdtls.extract_constant, "Extract constant")
    map("v", "<leader>jm", function()
      jdtls.extract_method(true)
    end, "Extract method")
    map("n", "<leader>jt", jdtls.test_class, "Test class")
    map("n", "<leader>jn", jdtls.test_nearest_method, "Test nearest method")
  end,
}

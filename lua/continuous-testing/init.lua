local commands = require("continuous-testing.commands")

vim.fn.sign_define("test_success", { text = "" })
vim.fn.sign_define("test_failure", { text = "" })
vim.fn.sign_define("test_skipped", { text = "" })
vim.fn.sign_define("test_other", { text = "" })
vim.fn.sign_define("test_running", { text = "" })

local M = {}

M.setup = function(config)
    require("continuous-testing.config").set_user_specific_config(config or {})

    commands.setup()
end

return M

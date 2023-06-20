local commands = require("continuous-testing.commands")

local M = {}

M.setup = function(config)
    require("continuous-testing.config").set_config(config or {})

    vim.cmd([[
      hi default ContinuousTestingPassed ctermfg=Green guifg=#96F291
      hi default ContinuousTestingFailed ctermfg=Red guifg=#F70067
      hi default ContinuousTestingRunning ctermfg=Yellow guifg=#FFEC63
      hi default ContinuousTestingSkipped ctermfg=Cyan guifg=#00f1f5
    ]])

    vim.fn.sign_define(
        "test_success",
        { text = "󰄬", texthl = "ContinuousTestingPassed" }
    )

    vim.fn.sign_define(
        "test_failure",
        { text = "󰅖", texthl = "ContinuousTestingFailed" }
    )

    vim.fn.sign_define(
        "test_skipped",
        { text = "󰒬", texthl = "ContinuousTestingSkipped" }
    )

    vim.fn.sign_define(
        "test_running",
        { text = "󰑐", texthl = "ContinuousTestingRunning" }
    )

    vim.fn.sign_define("test_other", { text = "" })

    commands.setup()
end

return M

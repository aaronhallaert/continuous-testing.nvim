local config_helper = require("continuous-testing.config")
local dialog = require("continuous-testing.dialog")
local notify = require("continuous-testing.notify")
local utils = require("continuous-testing.utils")

local CONTINUOUS_TESTING = "ContinuousTesting"
local CONTINUOUS_TESTING_DIALOG = "ContinuousTestingDialog"
local STOP_CONTINUOUS_TESTING = "StopContinuousTesting"

local M = {}

local group = vim.api.nvim_create_augroup(CONTINUOUS_TESTING, { clear = true })

local continuous_testing_active = false
local autocmd = nil
local testing_module = nil

local stop_continuous_testing_cmd = function(bufnr)
    return function()
        continuous_testing_active = false

        vim.api.nvim_del_autocmd(autocmd)
        vim.api.nvim_del_user_command(STOP_CONTINUOUS_TESTING)
        vim.api.nvim_buf_del_user_command(bufnr, CONTINUOUS_TESTING_DIALOG)

        testing_module.clear_test_results()
    end
end

local continuous_testing_dialog_cmd = function()
    local message = testing_module.testing_dialog_message()

    if message == nil then
        notify("No content to fill the dialog with", vim.log.levels.WARN)
        return
    end

    dialog.open(message)
end

local create_autocmd = function(bufnr, cmd)
    continuous_testing_active = true

    autocmd = vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        pattern = "*.rb",
        callback = testing_module.test_result_handler(bufnr, cmd),
    })
end

local continuous_testing_cmd = function()
    if continuous_testing_active then
        notify("ContinuousTesting is already active", vim.log.levels.INFO)
        return
    end

    local config = config_helper.get_config()

    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.fn.expand("%")
    local filetype = vim.fn.expand("%:e")

    testing_module =
        require("continuous-testing.languages").resolve_testing_module_by_file_type(
            filetype
        )

    if testing_module == nil then
        return
    end

    create_autocmd(
        bufnr,
        utils.inject_file_to_test_command(config.ruby.test_cmd, filename)
    )

    vim.api.nvim_create_user_command(
        STOP_CONTINUOUS_TESTING,
        stop_continuous_testing_cmd(bufnr),
        {}
    )

    vim.api.nvim_buf_create_user_command(
        bufnr,
        CONTINUOUS_TESTING_DIALOG,
        continuous_testing_dialog_cmd,
        {}
    )
end

M.setup = function()
    vim.api.nvim_create_user_command(
        CONTINUOUS_TESTING,
        continuous_testing_cmd,
        {}
    )
end

return M

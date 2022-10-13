local dialog = require("continuous-testing.utils.dialog")
local notify = require("continuous-testing.utils.notify")
local state = require("continuous-testing.state")

local ATTACHED_TESTS = "AttachedContinuousTests"
local CONTINUOUS_TESTING = "ContinuousTesting"
local CONTINUOUS_TESTING_DIALOG = "ContinuousTestingDialog"
local STOP_CONTINUOUS_TESTING = "StopContinuousTesting"

local M = {}

local group = vim.api.nvim_create_augroup(CONTINUOUS_TESTING, { clear = true })

local autocmd = nil
local testing_module = nil

-- Stop continuous testing for the current test file
-- @param bufnr The bufnr of the test file
local stop_continuous_testing_cmd = function(bufnr)
    return function()
        testing_module.clear_test_results(bufnr)
        vim.api.nvim_del_autocmd(autocmd)
        vim.api.nvim_buf_del_user_command(bufnr, STOP_CONTINUOUS_TESTING)
        vim.api.nvim_buf_del_user_command(bufnr, CONTINUOUS_TESTING_DIALOG)

        state.detach(bufnr)
    end
end

-- Open test output dialog
-- @param bufnr The bufnr of the test file
local open_test_output_dialog_cmd = function(bufnr)
    return function()
        local line_pos = vim.fn.line(".")
        local message = testing_module.testing_dialog_message(bufnr, line_pos)

        if message == nil then
            notify("No content to fill the dialog with", vim.log.levels.WARN)
            return
        end

        dialog.open(message)
    end
end

-- Run the test file (bufnr) whenever a file is saved with a certain pattern
-- @param bufnr Bufnr of test file
-- @param cmd Test command to execute
-- @param pattern Execute the autocmd on save for files with this pattern
local attach_on_save_autocmd = function(bufnr, cmd, pattern)
    state.attach(bufnr)

    autocmd = vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        pattern = pattern,
        callback = testing_module.test_result_handler(bufnr, cmd),
    })
end

local attach_test = function()
    local bufnr = vim.api.nvim_get_current_buf()

    if state.is_attached(bufnr) then
        notify("ContinuousTesting is already active", vim.log.levels.WARN)
        return
    end

    local filetype = vim.fn.expand("%:e")
    local filetype_pattern = "*." .. filetype

    testing_module =
        require("continuous-testing.languages").resolve_testing_module_by_file_type(
            filetype
        )

    if testing_module == nil then
        notify("No testing module found", vim.log.levels.WARN)
        return
    end

    -- Attach an autocmd to all files with filetype_pattern, which will run the test
    attach_on_save_autocmd(
        bufnr,
        testing_module.command(bufnr),
        filetype_pattern
    )

    -- Create a user command to stop the continuous testing on the test file
    vim.api.nvim_buf_create_user_command(
        bufnr,
        STOP_CONTINUOUS_TESTING,
        stop_continuous_testing_cmd(bufnr),
        {}
    )

    -- Create a user command
    vim.api.nvim_buf_create_user_command(
        bufnr,
        CONTINUOUS_TESTING_DIALOG,
        open_test_output_dialog_cmd(bufnr),
        {}
    )
end

M.setup = function()
    vim.api.nvim_create_user_command(CONTINUOUS_TESTING, attach_test, {})

    vim.api.nvim_create_user_command(
        ATTACHED_TESTS,
        require("continuous-testing.telescope").open_attached_tests,
        {}
    )
end

return M

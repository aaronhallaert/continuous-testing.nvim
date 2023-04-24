local dialog = require("continuous-testing.utils.dialog")
local file_util = require("continuous-testing.utils.file")
local notify = require("continuous-testing.utils.notify")
local config = require("continuous-testing.config")
local state = require("continuous-testing.state")
local get_state = require("continuous-testing.state").get_state
local common = require("continuous-testing.languages.common")
local languages = require("continuous-testing.languages")

local ATTACHED_TESTS = "CTOverview"
local RUN_ATTACHED_TESTS = "CTSingleRun"
local CONTINUOUS_TESTING = "CTAttach"
local CONTINUOUS_TESTING_DIALOG = "CTDialog"
local STOP_CONTINUOUS_TESTING = "CTDetach"

local FILE_TYPE_PATTERNS = {
    rb = "*.rb",
    js = { "*.js", "*.jsx", "*.ts", "*.tsx" },
    jsx = { "*.js", "*.jsx", "*.ts", "*.tsx" },
    ts = { "*.js", "*.jsx", "*.ts", "*.tsx" },
    tsx = { "*.js", "*.jsx", "*.ts", "*.tsx" },
}

local M = {}

local group = vim.api.nvim_create_augroup(CONTINUOUS_TESTING, { clear = true })

---Stop continuous testing for the current test file
---@param bufnr number
local stop_continuous_testing_cmd = function(bufnr)
    return function()
        common.cleanup_previous_test_run(bufnr)
        vim.api.nvim_del_autocmd(get_state(bufnr).ct_meta.autocmd)
        vim.api.nvim_buf_del_user_command(bufnr, STOP_CONTINUOUS_TESTING)
        vim.api.nvim_buf_del_user_command(bufnr, CONTINUOUS_TESTING_DIALOG)

        state.detach(bufnr)
    end
end

---Open test output dialog
---@param bufnr number The bufnr of the test file
local open_test_output_dialog_cmd = function(bufnr)
    local testing_module = get_state(bufnr).ct_meta.testing_module
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

---
---Framework for test runners
---
---@param bufnr number Bufnr of test file
---@param cmd string Test command to execute
---@param pattern string Execute the autocmd on save for files with this pattern
local attach_on_save_autocmd = function(bufnr, cmd, pattern)
    local testing_module = get_state(bufnr).ct_meta.testing_module
    testing_module.initialize_state(bufnr)

    local handle_test = function()
        common.cleanup_previous_test_run(bufnr)
        testing_module.initialize_run(bufnr)

        local job_id = testing_module.test_result_handler(bufnr, cmd)
        get_state(bufnr).ct_meta.job = job_id
    end

    local autocmd_id = vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        pattern = pattern,
        callback = handle_test,
    })

    get_state(bufnr).ct_meta.autocmd = autocmd_id

    notify({ "Added " .. file_util.file_name(bufnr) }, vim.log.levels.INFO)

    vim.api.nvim_create_autocmd("BufUnload", {
        group = group,
        buffer = bufnr,
        callback = stop_continuous_testing_cmd(bufnr),
    })

    if config.get_config().run_tests_on_setup then
        handle_test()
    end
end

local attach_test = function()
    local bufnr = vim.api.nvim_get_current_buf()

    if state.is_attached(bufnr) then
        notify("ContinuousTesting is already active", vim.log.levels.WARN)
        return
    end

    state.attach(bufnr)

    local filetype_extension = vim.fn.expand("%:e")

    local tm = languages.resolve_testing_module_by_file_type(filetype_extension)

    get_state(bufnr).ct_meta.testing_module = tm

    if tm == nil then
        notify("No testing module found for this filetype", vim.log.levels.WARN)
        return
    end

    -- Attach an autocmd to all files with filetype_pattern, which will run the test
    attach_on_save_autocmd(
        bufnr,
        tm.command(bufnr),
        FILE_TYPE_PATTERNS[filetype_extension]
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

    vim.api.nvim_create_user_command(
        RUN_ATTACHED_TESTS,
        require("continuous-testing.telescope").open_attached_test_instances,
        {}
    )
end

return M

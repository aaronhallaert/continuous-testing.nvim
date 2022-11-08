local update_state = require("continuous-testing.state").update_state
local state = require("continuous-testing.state").get_state

local M = {}

M.TEST_RESULTS = { SUCCESS = "passed", FAILED = "failed", SKIPPED = "pending" }

M.ns = vim.api.nvim_create_namespace("ContinuousTesting")

local sign_id_for_status = function(test_result)
    local sign_name
    if test_result == M.TEST_RESULTS.SUCCESS then
        sign_name = "test_success"
    elseif test_result == M.TEST_RESULTS.FAILED then
        sign_name = "test_failure"
    elseif test_result == M.TEST_RESULTS.SKIPPED then
        sign_name = "test_skipped"
    else
        sign_name = "test_other"
    end
    return sign_name
end

M.place_result_sign = function(bufnr, line, status)
    vim.fn.sign_unplace("", { buffer = bufnr, id = line })

    vim.fn.sign_place(
        line,
        "continuous_tests",
        sign_id_for_status(status),
        bufnr,
        { lnum = line, priority = 100 }
    )
end

M.place_start_sign = function(bufnr, line)
    vim.fn.sign_place(
        line,
        "continuous_tests", -- use default sign group so we can share animation instances.
        "test_running",
        bufnr,
        { lnum = line + 1, priority = 100 }
    )

    state(bufnr).telescope_status = "🏃"
end

M.publish_diagnostics = function(bufnr)
    vim.diagnostic.set(M.ns, bufnr, state(bufnr).diagnostics, {})
end

M.add_diagnostics_to_state = function(bufnr, line, status, source)
    local test_state = state(bufnr)
    local severity = vim.diagnostic.severity.ERROR
    local message = "Test Failed"

    if status == M.TEST_RESULTS.SUCCESS then
        severity = vim.diagnostic.severity.INFO
        message = "Test Succeeded"
    elseif status == M.TEST_RESULTS.SKIPPED then
        severity = vim.diagnostic.severity.WARN
        message = "Test Skipped"
    end

    if severity ~= vim.diagnostic.severity.INFO then
        table.insert(test_state.diagnostics, {
            bufnr = bufnr,
            lnum = line - 1,
            col = 0,
            severity = severity,
            source = source,
            message = message,
            user_data = {},
        })
    end
end

M.cleanup_previous_test_run = function(bufnr)
    if state(bufnr)["job"] ~= nil then
        vim.fn.jobstop(state(bufnr)["job"])
    end

    vim.diagnostic.reset(M.ns, bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
    vim.fn.sign_unplace("continuous_tests", { buffer = bufnr })

    update_state(bufnr, { diagnostics = {}, tests = {}, telescope_status = "" })
end

return M

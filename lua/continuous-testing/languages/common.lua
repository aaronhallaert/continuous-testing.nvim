local state = require("continuous-testing.state").get_state
local table_util = require("continuous-testing.utils.table")

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

-- Add result sign for a test in a file
--
-- @param bufnr Buffer number
-- @param line Line number of the test
-- @param status One of TEST_RESULTS["passed", "failed" ,"pending"]
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

-- Add start sign to a test
--
-- @param bufnr Buffer number
-- @param line Line number of test
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

-- Add test result as diagnostics
-- Eventually, after all diagnostics are added, call the `publish_diagnostics` method!
--
-- @param bufnr Buffer number
-- @param line Line number of test
-- @param status One of `TEST_RESULTS`["passed", "failed", "pending"]
-- @param source One of the supported test frameworks ("rspec", "vitest" ...)
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

-- Stop running test jobs
-- Clean up diagnostics, signs and continuous-testing state
--
-- @param bufnr
M.cleanup_previous_test_run = function(bufnr, opts)
    opts = opts or { clear_state = true }

    if state(bufnr)["job"] ~= nil then
        vim.fn.jobstop(state(bufnr).ct_meta.job)
    end

    vim.diagnostic.reset(M.ns, bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
    vim.fn.sign_unplace("continuous_tests", { buffer = bufnr })

    if opts.clear_state then
        table_util.merge_table(state(bufnr), {
            diagnostics = {},
            test_results = {},
            telescope_status = "",
        })
    end
end

return M

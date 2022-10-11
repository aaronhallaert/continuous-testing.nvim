-- namespace for diagnostics
local ns = vim.api.nvim_create_namespace("ContinuousRubyTesting")
local state = require("continuous-testing.state").get_state
local update_state = require("continuous-testing.state").update_state

local M = {}

local EMPTY_STATE = { version = nil, seed = nil, tests = {}, diagnostics = {} }
local TEST_RESULTS =
    { SUCCESS = "passed", FAILED = "failed", SKIPPED = "pending" }

local function get_sign(test_result)
    local sign_name
    if test_result == TEST_RESULTS.SUCCESS then
        sign_name = "test_success"
    elseif test_result == TEST_RESULTS.FAILED then
        sign_name = "test_failure"
    elseif test_result == TEST_RESULTS.SKIPPED then
        sign_name = "test_skipped"
    else
        sign_name = "test_other"
    end
    return sign_name
end

-- clean up specific tests state of buffer
-- @param bufnr Bufnr of test file
M.clear_test_results = function(bufnr)
    vim.diagnostic.reset(ns, bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.fn.sign_unplace("continuous_tests", { buffer = bufnr })

    update_state(bufnr, table.deepcopy(EMPTY_STATE))
end

local on_exit_callback = function(bufnr)
    return function()
        for _, test in pairs(state(bufnr).tests) do
            local severity = vim.diagnostic.severity.ERROR
            local message = "Test Failed"

            if test.status == TEST_RESULTS.SUCCESS then
                severity = vim.diagnostic.severity.INFO
                message = "Test Succeeded"
            elseif test.status == TEST_RESULTS.SKIPPED then
                severity = vim.diagnostic.severity.WARN
                message = "Test Skipped"
            end

            table.insert(state(bufnr).diagnostics, {
                bufnr = bufnr,
                lnum = test.line_number - 1,
                col = 0,
                severity = severity,
                source = "rspec",
                message = message,
                user_data = {},
            })
        end

        vim.diagnostic.set(ns, bufnr, state(bufnr).diagnostics, {})
    end
end

M.testing_dialog_message = function(bufnr)
    local test_key = "./" .. vim.fn.expand("%") .. ":" .. vim.fn.line(".")

    local test = state(bufnr).tests[test_key]
    if not test or test.status ~= TEST_RESULTS.FAILED then
        return
    end

    local message = {
        "Test: " .. test.description,
        "Location: " .. test.file_path .. ":" .. test.line_number,
        "Runtime: " .. test.run_time,
        "Seed: " .. state(bufnr).seed,
        "",
        "Exception: " .. test.exception.class,
        "Message:",
    }

    -- Splitting on new lines because the message array cannot contain any when
    -- setting lines.
    for line in string.gmatch(test.exception.message, "[^\r\n]+") do
        table.insert(message, line)
    end

    table.insert(message, "")
    table.insert(message, "Backtrace:")

    if test.exception.backtrace ~= vim.NIL then
        for _, line in ipairs(test.exception.backtrace) do
            for backtrace in string.gmatch(line, "[^\r\n]+") do
                table.insert(message, backtrace)
            end
        end
    end

    return message
end

M.test_result_handler = function(bufnr, cmd)
    vim.notify(
        { "Adding " .. vim.fn.expand("#" .. bufnr .. ":t") },
        vim.log.levels.INFO
    )

    local init_state = table.deepcopy(EMPTY_STATE)
    init_state["bufnr"] = bufnr
    update_state(bufnr, init_state)

    return function()
        M.clear_test_results(bufnr)

        local append_data = function(_, data)
            if not data then
                vim.notify({ "No data for test" }, vim.log.levels.WARN)
                return
            end

            for _, line in ipairs(data) do
                if not string.find(line, "{") then
                    return
                end

                local decoded = vim.json.decode(line)

                state(bufnr).version = decoded.version
                state(bufnr).seed = decoded.seed

                for _, test in pairs(decoded.examples) do
                    state(bufnr).tests[test.file_path .. ":" .. test.line_number] =
                        test

                    vim.fn.sign_place(
                        test.file_path .. ":" .. test.line_number,
                        "continuous_tests", -- use default sign group so we can share animation instances.
                        get_sign(test.status),
                        bufnr,
                        { lnum = test.line_number, priority = 100 }
                    )
                end

                local log_level = decoded.summary.failure_count > 0
                        and vim.log.levels.ERROR
                    or vim.log.levels.INFO
                vim.notify(
                    decoded.summary_line,
                    log_level,
                    { title = "RSpec " .. vim.fn.expand("#" .. bufnr .. ":t") }
                )
            end
        end

        vim.fn.jobstart(cmd, {
            stdout_buffered = true,
            on_stdout = append_data,
            on_stderr = append_data,
            on_exit = on_exit_callback(bufnr),
        })
    end
end

return M

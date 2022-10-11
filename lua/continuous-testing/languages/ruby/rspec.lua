local M = {}

-- namespace for diagnostics
local ns = vim.api.nvim_create_namespace("ContinuousRubyTesting")

-- global state
-- version, seed, tests, diagnostics
local state = {}

local TEST_STATES =
    { SUCCESS = "passed", FAILED = "failed", SKIPPED = "pending" }

-- clean up specific tests state of buffer
-- @param bufnr Bufnr of test file
M.clear_test_results = function(bufnr)
    vim.diagnostic.reset(ns, bufnr)
    print(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

    state[bufnr].version = nil
    state[bufnr].seed = nil
    state[bufnr].tests = {}
    state[bufnr].diagnostics = {}
end

local on_exit_callback = function()
    for _, test in pairs(state.tests) do
        local severity = vim.diagnostic.severity.ERROR
        local message = "Test Failed"

        if test.status == TEST_STATES.SUCCESS then
            severity = vim.diagnostic.severity.INFO
            message = "Test Succeeded"
        elseif test.status == TEST_STATES.SKIPPED then
            severity = vim.diagnostic.severity.WARN
            message = "Test Skipped"
        end

        table.insert(state.diagnostics, {
            bufnr = state.bufnr,
            lnum = test.line_number - 1,
            col = 0,
            severity = severity,
            source = "rspec",
            message = message,
            user_data = {},
        })
    end

    vim.diagnostic.set(ns, state.bufnr, state.diagnostics, {})
end

M.testing_dialog_message = function()
    local test_key = "./" .. vim.fn.expand("%") .. ":" .. vim.fn.line(".")

    local test = state.tests[test_key]
    if not test or test.status ~= TEST_STATES.FAILED then
        return
    end

    local message = {
        "Test: " .. test.description,
        "Location: " .. test.file_path .. ":" .. test.line_number,
        "Runtime: " .. test.run_time,
        "Seed: " .. state.seed,
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
        { "Adding " .. vim.fn.expand("#" .. bufnr .. ":p") },
        vim.log.levels.INFO
    )

    state[bufnr] = {
        bufnr = bufnr,
        version = nil,
        seed = nil,
        tests = {},
        diagnostics = {},
    }

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

                state[bufnr].version = decoded.version
                state[bufnr].seed = decoded.seed

                for _, test in pairs(decoded.examples) do
                    state[bufnr].tests[test.file_path .. ":" .. test.line_number] =
                        test

                    local text
                    if test.status == TEST_STATES.SUCCESS then
                        text = { "✅" }
                    elseif test.status == TEST_STATES.FAILED then
                        text = { "❌" }
                    elseif test.status == TEST_STATES.SKIPPED then
                        text = { "⏭️" }
                    else
                        text = { "❓" }
                    end

                    vim.api.nvim_buf_set_extmark(
                        state[bufnr].bufnr,
                        ns,
                        test.line_number - 1,
                        0,
                        { virt_text = { text } }
                    )
                end

                local log_level = decoded.summary.failure_count > 0
                        and vim.log.levels.ERROR
                    or vim.log.levels.INFO
                vim.notify(decoded.summary_line, log_level, { title = "RSpec" })
            end
        end

        vim.fn.jobstart(cmd, {
            stdout_buffered = true,
            on_stdout = append_data,
            on_stderr = append_data,
            on_exit = on_exit_callback,
        })
    end
end

return M
local config = require("continuous-testing.config")
local state = require("continuous-testing.state").get_state

-- utils
local file_util = require("continuous-testing.utils.file")
local format = require("continuous-testing.utils.format")
local notify = require("continuous-testing.utils.notify")

-- implementation helper
local common = require("continuous-testing.languages.common")

local M = {}

local TEST_RESULTS =
    { SUCCESS = "passed", FAILED = "failed", SKIPPED = "pending" }

local ts_query_tests = vim.treesitter.parse_query(
    "ruby",
    [[
        (call
        method: (identifier) @id (#eq? @id "it")
        )
    ]]
)

local on_exit_callback = function(bufnr)
    return function(_, exit_code, _)
        -- exit_code 143 means SIGTERM
        if next(state(bufnr).tests) == nil and exit_code ~= 143 then
            notify({
                "No test results for " .. file_util.file_name(bufnr),
            }, vim.log.levels.ERROR)
        end

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

        vim.diagnostic.set(common.ns, bufnr, state(bufnr).diagnostics, {})
    end
end

M.testing_dialog_message = function(bufnr, line_position)
    local test_key = line_position

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
    notify({ "Adding " .. file_util.file_name(bufnr) }, vim.log.levels.INFO)

    return function()
        if state(bufnr)["job"] ~= nil then
            vim.fn.jobstop(state(bufnr)["job"])
        end

        common.clear_test_results(bufnr)

        local root = format.get_treesitter_root(bufnr, "ruby")

        for id, node in ts_query_tests:iter_captures(root, bufnr, 0, -1) do
            local name = ts_query_tests.captures[id]
            if name == "id" then
                -- {start row, start col, end row, end col}
                local range = { node:range() }
                vim.fn.sign_place(
                    range[1],
                    "continuous_tests", -- use default sign group so we can share animation instances.
                    "test_running",
                    bufnr,
                    { lnum = range[1] + 1, priority = 100 }
                )
            end
        end

        local append_data = function(_, data)
            if not data then
                notify({ "No data for test" }, vim.log.levels.WARN)
                return
            end

            for _, line in ipairs(data) do
                if string.find(line, "{") then
                    local decoded = vim.json.decode(line)

                    state(bufnr).version = decoded.version
                    state(bufnr).seed = decoded.seed

                    for _, test in pairs(decoded.examples) do
                        state(bufnr).tests[test.line_number] = test
                        vim.fn.sign_unplace(
                            "",
                            { buffer = bufnr, id = test.line_number }
                        )

                        vim.fn.sign_place(
                            test.line_number,
                            "continuous_tests", -- use default sign group so we can share animation instances.
                            common.get_sign(test.status, TEST_RESULTS),
                            bufnr,
                            { lnum = test.line_number, priority = 100 }
                        )
                    end

                    local log_level
                    if decoded.summary.failure_count > 0 then
                        log_level = vim.log.levels.ERROR
                        state(bufnr).telescope_status = "🚫"
                    else
                        log_level = vim.log.levels.INFO
                        state(bufnr).telescope_status = "✅"
                    end

                    notify(
                        decoded.summary_line,
                        log_level,
                        "RSpec " .. file_util.file_name(bufnr)
                    )
                end
            end
        end

        local job_id = vim.fn.jobstart(cmd, {
            stdout_buffered = true,
            on_stdout = append_data,
            on_stderr = append_data,
            on_exit = on_exit_callback(bufnr),
        })

        state(bufnr)["job"] = job_id
    end
end

M.command = function(bufnr)
    local path = file_util.relative_path(bufnr)
    return format.inject_file_to_test_command(
        config.get_config().ruby.test_cmd,
        path
    ) .. " --format  json --no-fail-fast"
end

return M

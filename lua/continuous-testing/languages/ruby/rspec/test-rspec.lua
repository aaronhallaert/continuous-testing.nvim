local state = require("continuous-testing.state").get_state
local notify = require("continuous-testing.utils.notify")
local common = require("continuous-testing.languages.common")
local file_util = require("continuous-testing.utils.file")

local state_rspec =
    require("continuous-testing.languages.ruby.rspec.state-rspec")

local tmp_output = ""

-- Parses stdout and scans for `{}` which includes the json test results
local append_data = function(bufnr)
    return function(_, data)
        local buffer_test_state = state(bufnr)
        ---@cast buffer_test_state RspecBufferTestState

        if not data then
            notify({ "No data for test" }, vim.log.levels.WARN)
            return
        end

        for _, line in ipairs(data) do
            tmp_output = tmp_output .. "\n" .. line
            if string.find(line, "rubocop ended") == 1 then
                buffer_test_state.phase = "test"
            elseif string.find(line, "{") == 1 then
                buffer_test_state.phase = "parse_test"
                local json_data = vim.json.decode(line)
                state_rspec.generate_tests_state(bufnr, json_data)
            end
        end
    end
end

local on_exit_callback = function(bufnr, command)
    return function(_, exit_code, _)
        local buffer_test_state = state(bufnr)
        ---@cast buffer_test_state RspecBufferTestState

        if buffer_test_state.phase == "pre_test" and exit_code == 1 then
            notify({
                "Breakpoint detected",
                ":CTSingleRun to run a test interactively",
            }, vim.log.levels.WARN)

            common.cleanup_previous_test_run(bufnr, { clear_state = false })

            return
        elseif buffer_test_state.phase == "test" and exit_code == 1 then
            notify({
                "No test results for " .. file_util.file_name(bufnr),
                "See `:messages` for more info",
            }, vim.log.levels.ERROR)

            common.cleanup_previous_test_run(bufnr, { clear_state = false })
            print(">> " .. command)
            error(tmp_output, vim.log.levels.ERROR)
            tmp_output = ""

            return
        elseif exit_code == 143 then
            -- exit_code 143 means SIGTERM
            return
        end

        for line_number, test in pairs(buffer_test_state.test_results) do
            common.place_result_sign(bufnr, line_number, test.status)
            common.add_diagnostics_to_state(
                bufnr,
                line_number,
                test.status,
                "rspec"
            )
        end

        notify(
            buffer_test_state.summary_line,
            buffer_test_state.summary_log_level,
            "RSpec " .. file_util.file_name(bufnr)
        )

        common.publish_diagnostics(bufnr)
        state(bufnr).phase = "post_test"
    end
end

local M = {}

M.run_test_file = function(bufnr, cmd)
    local job_id = vim.fn.jobstart(
        "rubocop --only Lint/Debugger && echo 'rubocop ended' &&" .. cmd,
        {
            stdout_buffered = true,
            on_stdout = append_data(bufnr),
            on_stderr = append_data(bufnr),
            on_exit = on_exit_callback(bufnr, cmd),
        }
    )

    return job_id
end

return M

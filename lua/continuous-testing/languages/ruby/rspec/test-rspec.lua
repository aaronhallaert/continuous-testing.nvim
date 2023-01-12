local state = require("continuous-testing.state").get_state
local notify = require("continuous-testing.utils.notify")
local common = require("continuous-testing.languages.common")
local file_util = require("continuous-testing.utils.file")
local config = require("continuous-testing.config")

local state_rspec =
    require("continuous-testing.languages.ruby.rspec.state-rspec")

local tmp_output = ""

local append_data = function(bufnr)
    return function(_, data)
        if not data then
            notify({ "No data for test" }, vim.log.levels.WARN)
            return
        end

        for _, line in ipairs(data) do
            tmp_output = tmp_output .. "\n" .. line
            if string.find(line, "{") == 1 then
                state(bufnr).phase = "parse_test"
                local json_data = vim.json.decode(line)
                state_rspec.generate_tests_state(bufnr, json_data)
            end
        end
    end
end

local on_exit_callback = function(bufnr)
    return function(_, exit_code, _)
        -- TODO: this is still partly common code, if the state is properly set up, this can also be extracted
        -- exit_code 143 means SIGTERM
        if state(bufnr).phase == "test" and exit_code == 1 then
            notify({
                "Breakpoint detected",
            }, vim.log.levels.WARN)
            require("continuous-testing.telescope").open_attached_test_instances(
                config.get_config().ruby.test_cmd
            )
            common.cleanup_previous_test_run(bufnr)
            return
        elseif next(state(bufnr).tests) == nil and exit_code ~= 143 then
            notify({
                "No test results for " .. file_util.file_name(bufnr),
                "See `:messages` for more info",
            }, vim.log.levels.ERROR)

            common.cleanup_previous_test_run(bufnr)
            print(">> " .. M.command(bufnr))
            error(tmp_output, vim.log.levels.ERROR)
            tmp_output = ""
            return
        end

        local test_state = state(bufnr)
        for line_number, test in pairs(test_state.tests) do
            common.place_result_sign(bufnr, line_number, test.status)
            common.add_diagnostics_to_state(
                bufnr,
                line_number,
                test.status,
                "rspec"
            )
        end

        notify(
            test_state.summary_line,
            test_state.summary_log_level,
            "RSpec " .. file_util.file_name(bufnr)
        )

        common.publish_diagnostics(bufnr)
        state(bufnr).phase = "post_test"
    end
end

M = {}

M.run_test_file = function(bufnr, cmd)
    state(bufnr).phase = "test"
    local job_id = vim.fn.jobstart("rubocop --only Lint/Debugger &&" .. cmd, {
        stdout_buffered = true,
        on_stdout = append_data(bufnr),
        on_stderr = append_data(bufnr),
        on_exit = on_exit_callback(bufnr),
    })

    return job_id
end

return M

local config = require("continuous-testing.config")
local state = require("continuous-testing.state").get_state

-- utils
local file_util = require("continuous-testing.utils.file")
local format = require("continuous-testing.utils.format")
local notify = require("continuous-testing.utils.notify")

-- implementation helper
local common = require("continuous-testing.languages.common")
local tmp_output = ""

local M = {}

local generate_tests_state = function(bufnr, json_data)
    state(bufnr).version = json_data.version
    state(bufnr).seed = json_data.seed

    for _, test in pairs(json_data.examples) do
        state(bufnr).tests[test.line_number] = test
    end

    local log_level
    if json_data.summary.failure_count > 0 then
        log_level = vim.log.levels.ERROR
        state(bufnr).telescope_status = "🚫"
    else
        log_level = vim.log.levels.INFO
        state(bufnr).telescope_status = "✅"
    end

    state(bufnr).summary_line = json_data.summary_line
    state(bufnr).summary_log_level = log_level
end

M.place_start_signs = function(bufnr)
    local ts_query_tests = vim.treesitter.parse_query(
        "ruby",
        [[
        (call
            method: (identifier) @id (#match? @id "^(it|xit)$")
            arguments: (argument_list (string (string_content) @title))
        )
    ]]
    )

    local root = format.get_treesitter_root(bufnr, "ruby")

    for id, node in ts_query_tests:iter_captures(root, bufnr, 0, -1) do
        local name = ts_query_tests.captures[id]
        if name == "id" then
            -- {start row, start col, end row, end col}
            local range = { node:range() }
            common.place_start_sign(bufnr, range[1])
        elseif name == "title" then
            local title = vim.treesitter.query.get_node_text(node, bufnr)
            local range = { node:range() }
            state(bufnr).tests[range[1] + 1] =
                { status = "pending", title = title }
            state(bufnr).phase = "pre_test"
        end
    end
end

M.testing_dialog_message = function(bufnr, line_position)
    local test = state(bufnr).tests[line_position]
    if not test or test.status ~= common.TEST_RESULTS.FAILED then
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
    local append_data = function(_, data)
        if not data then
            notify({ "No data for test" }, vim.log.levels.WARN)
            return
        end

        for _, line in ipairs(data) do
            tmp_output = tmp_output .. "\n" .. line
            if string.find(line, "{") == 1 then
                state(bufnr).phase = "parse_test"
                local json_data = vim.json.decode(line)
                generate_tests_state(bufnr, json_data)
            end
        end
    end

    local on_exit_callback = function()
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
            elseif
                (next(state(bufnr).tests) == nil and exit_code ~= 143)
                or exit_code == 1
            then
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

    state(bufnr).phase = "test"
    local job_id = vim.fn.jobstart("rubocop --only Lint/Debugger &&" .. cmd, {
        stdout_buffered = true,
        on_stdout = append_data,
        on_stderr = append_data,
        on_exit = on_exit_callback(),
    })

    return job_id
end

M.command = function(bufnr)
    local path = file_util.relative_path(bufnr)
    return format.inject_file_to_test_command(
        config.get_config().ruby.test_cmd,
        path
    ) .. " --format  json --no-fail-fast"
end

return M

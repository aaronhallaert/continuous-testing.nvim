local config = require("continuous-testing.config")
local state = require("continuous-testing.state").get_state

-- utils
local table_util = require("continuous-testing.utils.table")
local file_util = require("continuous-testing.utils.file")
local format = require("continuous-testing.utils.format")
local notify = require("continuous-testing.utils.notify")

-- implementation helpers
local common = require("continuous-testing.languages.common")

local OUTPUT_FILE = "/tmp/vitest_test.json"

local M = {}

local ts_query_tests = vim.treesitter.parse_query(
    "javascript",
    [[
    (expression_statement
      (call_expression
        function: (identifier) @id (#eq? @id "it")
        arguments: (arguments
            (string
              (string_fragment) @str
            )
          )
        )
    )
    ]]
)

M.place_start_signs = function(bufnr)
    local root = format.get_treesitter_root(bufnr, "javascript")

    for id, node in ts_query_tests:iter_captures(root, bufnr, 0, -1) do
        local name = ts_query_tests.captures[id]
        if name == "str" then
            -- {start row, start col, end row, end col}
            local range = { node:range() }
            common.place_start_sign(bufnr, range[1])
        end
    end
end

-- updates state `tests` for the specified buffer from outputfile
local generate_tests_state = function(bufnr)
    -- open json file
    local test_output = file_util.get_json_table(OUTPUT_FILE)
    if test_output == nil then
        notify(
            { "No data for test" },
            vim.log.levels.WARN,
            file_util.file_name(bufnr)
        )
        return
    end

    local test_table = {}
    -- search the line number for every test_output
    for _, test in ipairs(test_output.testResults[1].assertionResults) do
        local root = format.get_treesitter_root(bufnr, "javascript")

        -- search line number with treesitter
        local line_number = function()
            for id, node in ts_query_tests:iter_captures(root, bufnr, 0, -1) do
                local name = ts_query_tests.captures[id]
                if name == "str" then
                    -- {start row, start col, end row, end col}
                    local range = { node:range() }
                    local match = vim.treesitter.get_node_text(node, bufnr)
                    if string.find(test.fullName, match) then
                        return range[1]
                    end
                end
            end
        end

        local line = line_number() + 1
        test_table[line] = test
    end

    table_util.merge_table(state(bufnr), { tests = test_table })
    test_output.testResults = nil
    table_util.merge_table(state(bufnr), test_output)

    local log_level
    local message

    if test_output.numFailedTests > 0 then
        log_level = vim.log.levels.ERROR
        message = test_output.numFailedTests .. " failing tests"
        state(bufnr).telescope_status = "🚫"
    else
        log_level = vim.log.levels.INFO
        state(bufnr).telescope_status = "✅"
        message = "All tests passed"
    end
    state(bufnr).summary_line = message
    state(bufnr).summary_log_level = log_level
end

M.testing_dialog_message = function(bufnr, line_position)
    local message = state(bufnr).tests[line_position].failureMessages

    if message == nil then
        message = { "No failure found" }
    end

    return message
end

M.test_result_handler = function(bufnr, cmd)
    local on_exit_callback = function()
        return function(_, exit_code, _)
            generate_tests_state(bufnr)

            local test_state = state(bufnr)

            -- exit_code 143 means SIGTERM
            if next(test_state.tests) == nil and exit_code ~= 143 then
                common.cleanup_previous_test_run(bufnr)
                notify({
                    "No test results for " .. file_util.file_name(bufnr),
                }, vim.log.levels.ERROR)
            end

            for line_number, test in pairs(test_state.tests) do
                common.place_result_sign(bufnr, line_number, test.status)
                common.add_diagnostics_to_state(
                    bufnr,
                    line_number,
                    test.status,
                    "vitest"
                )
            end

            notify(
                test_state.summary_line,
                test_state.summary_log_level,
                "Vitest " .. file_util.file_name(bufnr)
            )

            common.publish_diagnostics(bufnr)
        end
    end

    -- Environment where test will be executed
    local cwd =
        file_util.find_package_json_ancestor(file_util.absolute_path(bufnr))

    -- Relative cwd to remove from passed file paths
    local relative_cwd =
        file_util.find_package_json_ancestor(file_util.relative_path(bufnr))

    if relative_cwd ~= nil then
        cmd = string.gsub(cmd, relative_cwd .. "/", "")
    end

    local job_id = vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        cwd = cwd,
        on_exit = on_exit_callback(),
    })

    return job_id
end

M.command = function(bufnr)
    local path = file_util.relative_path(bufnr)
    local js_config = config.get_config().javascript

    -- search for rootfolder to pass to vitest arguments
    local root_folder =
        file_util.find_first_ancestor(path, js_config.root_pattern)

    local c = format.inject_file_to_test_command(js_config.test_cmd, path)
        .. " --outputFile="
        .. OUTPUT_FILE

    if root_folder ~= nil then
        c = c .. " --root=" .. root_folder
    end

    c = c .. " --reporter=verbose  --reporter=json"

    return c
end

return M

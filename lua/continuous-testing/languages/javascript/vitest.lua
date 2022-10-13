local config = require("continuous-testing.config")
local state = require("continuous-testing.state").get_state

-- utils
local table_util = require("continuous-testing.utils.table")
local file_util = require("continuous-testing.utils.file")
local format = require("continuous-testing.utils.format")
local notify = require("continuous-testing.utils.notify")

-- implementation helpers
local common = require("continuous-testing.languages.common")

local TEST_RESULTS =
    { SUCCESS = "passed", FAILED = "failed", SKIPPED = "pending" }

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

-- returns a table with key (linenumber) and value (testTable)
local generate_state = function(bufnr)
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
end

local on_exit_callback = function(bufnr)
    return function(_, exit_code, _)
        generate_state(bufnr)
        local test_state = state(bufnr)

        --exit_code 143 means SIGTERM
        if next(test_state.tests) == nil and exit_code ~= 143 then
            notify({
                "No test results for " .. file_util.file_name(bufnr),
            }, vim.log.levels.ERROR)
        end

        for line, test in pairs(test_state.tests) do
            local severity = vim.diagnostic.severity.ERROR
            local message = "Test Failed"

            if test.status == TEST_RESULTS.SUCCESS then
                severity = vim.diagnostic.severity.INFO
                message = "Test Succeeded"
            elseif test.status == TEST_RESULTS.SKIPPED then
                severity = vim.diagnostic.severity.WARN
                message = "Test Skipped"
            end

            vim.fn.sign_unplace("", { buffer = bufnr, id = line })

            vim.fn.sign_place(
                line,
                "continuous_tests", -- use default sign group so we can share animation instances.
                common.get_sign(test.status, TEST_RESULTS),
                bufnr,
                { lnum = line, priority = 100 }
            )

            if severity ~= vim.diagnostic.severity.INFO then
                table.insert(test_state.diagnostics, {
                    bufnr = bufnr,
                    lnum = line - 1,
                    col = 0,
                    severity = severity,
                    source = "vitest",
                    message = message,
                    user_data = {},
                })
            end
        end

        local log_level
        local message

        if test_state.numFailedTests > 0 then
            log_level = vim.log.levels.ERROR
            message = test_state.numFailedTests .. " failing tests"
            state(bufnr).telescope_status = "🚫"
        else
            log_level = vim.log.levels.INFO
            state(bufnr).telescope_status = "✅"
            message = "All tests passed"
        end

        notify(message, log_level, "Vitest " .. file_util.file_name(bufnr))
        vim.diagnostic.set(common.ns, bufnr, test_state.diagnostics, {})
    end
end

M.testing_dialog_message = function(bufnr, line_position)
    local message = state(bufnr).tests[line_position].failureMessages

    if message == nil then
        message = { "No failure found" }
    end

    return message
end

M.test_result_handler = function(bufnr, cmd)
    return function()
        if state(bufnr)["job"] ~= nil then
            vim.fn.jobstop(state(bufnr)["job"])
        end

        common.clear_test_results(bufnr)

        local root = format.get_treesitter_root(bufnr, "javascript")

        for id, node in ts_query_tests:iter_captures(root, bufnr, 0, -1) do
            local name = ts_query_tests.captures[id]
            if name == "str" then
                -- {start row, start col, end row, end col}
                local range = { node:range() }
                vim.fn.sign_place(
                    range[1] + 1,
                    "continuous_tests", -- use default sign group so we can share animation instances.
                    "test_running",
                    bufnr,
                    { lnum = range[1] + 1, priority = 100 }
                )
            end
        end

        local cwd =
            file_util.find_package_json_ancestor(file_util.absolute_path(bufnr))

        local relative_cwd =
            file_util.find_package_json_ancestor(file_util.relative_path(bufnr))

        cmd = string.gsub(cmd, relative_cwd .. "/", "")

        local job_id = vim.fn.jobstart(cmd, {
            stdout_buffered = true,
            cwd = cwd,
            on_exit = on_exit_callback(bufnr),
        })

        state(bufnr)["job"] = job_id
    end
end

M.command = function(bufnr)
    local path = file_util.relative_path(bufnr)
    local js_config = config.get_config().javascript

    -- search for rootfolder
    local root_folder =
        file_util.find_first_ancestor(path, js_config.root_pattern)

    return format.inject_file_to_test_command(js_config.test_cmd, path)
        .. " --outputFile="
        .. OUTPUT_FILE
        .. " --root="
        .. root_folder
        .. " --reporter=verbose  --reporter=json"
end

return M

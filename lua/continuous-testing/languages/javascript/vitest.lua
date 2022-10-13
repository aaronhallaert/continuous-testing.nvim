local config = require("continuous-testing.config")
local state = require("continuous-testing.state").get_state
local update_state = require("continuous-testing.state").update_state

-- utils
local table_util = require("continuous-testing.utils.table")
local file_util = require("continuous-testing.utils.file")
local format = require("continuous-testing.utils.format")
local notify = require("continuous-testing.utils.notify")

-- namespace for diagnostics
local ns = vim.api.nvim_create_namespace("ContinuousVitestTesting")

local get_json_table = function(path)
    local file = io.open(path, "r")

    if file then
        -- read all contents of file into a string
        local contents = file:read("*a")
        local myTable = vim.json.decode(contents)
        io.close(file)
        return myTable
    end
    return nil
end

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

local output_file = "/tmp/vitest_test.json"

local EMPTY_STATE = {
    numTotalTests = nil,
    testResults = {},
    diagnostics = {},
}

local M = {}

M.clear_test_results = function(bufnr)
    vim.diagnostic.reset(ns, bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.fn.sign_unplace("continuous_tests", { buffer = bufnr })

    update_state(bufnr, table_util.deepcopy_table(EMPTY_STATE))
end

local get_treesitter_root = function(bufnr)
    local parser = vim.treesitter.get_parser(bufnr, "javascript", {})
    local tree = parser:parse()[1]
    return tree:root()
end

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
    local test_output = get_json_table(output_file)
    if test_output == nil then
        notify(
            { "No data for test" },
            vim.log.levels.WARN,
            vim.fn.expand("#" .. bufnr .. ":t")
        )
        return
    end

    local test_table = {}
    -- search the line number for every test_output
    for _, test in ipairs(test_output.testResults[1].assertionResults) do
        local root = get_treesitter_root(bufnr)
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
                get_sign(test.status),
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

        local log_level = test_state.numFailedTests > 0 and vim.log.levels.ERROR
            or vim.log.levels.INFO

        local message = test_state.numFailedTests > 0
                and test_state.numFailedTests .. " failing tests"
            or "All tests passed"

        notify(
            message,
            log_level,
            "Vitest " .. vim.fn.expand("#" .. bufnr .. ":t")
        )

        vim.diagnostic.set(ns, bufnr, test_state.diagnostics, {})
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
    local init_state = table_util.deepcopy_table(EMPTY_STATE)
    init_state["bufnr"] = bufnr
    update_state(bufnr, init_state)

    return function()
        if state(bufnr)["job"] ~= nil then
            vim.fn.jobstop(state(bufnr)["job"])
        end

        M.clear_test_results(bufnr)

        local root = get_treesitter_root(bufnr)
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
    local path = vim.fn.expand("#" .. bufnr .. ":f")
    local js_config = config.get_config().javascript

    -- search for rootfolder
    local root_folder =
        file_util.find_first_ancestor(path, js_config.root_pattern)

    return format.inject_file_to_test_command(js_config.test_cmd, path)
        .. " --outputFile="
        .. output_file
        .. " --root="
        .. root_folder
        .. " --reporter=verbose  --reporter=json"
end

return M

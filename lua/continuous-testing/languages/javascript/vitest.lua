-- namespace for diagnostics
local notify = require("continuous-testing.utils.notify")
local config = require("continuous-testing.config")

local table_util = require("continuous-testing.utils.table")
local file_util = require("continuous-testing.utils.file")
local format = require("continuous-testing.utils.format")

local state = require("continuous-testing.state").get_state
local update_state = require("continuous-testing.state").update_state
local ns = vim.api.nvim_create_namespace("ContinuousVitestTesting")

local get_json_table = function(path)
    local myTable = {}
    local file = io.open(path, "r")

    if file then
        -- read all contents of file into a string
        local contents = file:read("*a")
        myTable = vim.json.decode(contents)
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

local get_root = function(bufnr)
    local parser = vim.treesitter.get_parser(bufnr, "javascript", {})
    local tree = parser:parse()[1]
    return tree:root()
end

local on_exit_callback = function(bufnr)
    return function(_, exit_code, _)
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
        local new_state = state(bufnr)
        for k, v in pairs(test_output) do
            new_state[k] = v
        end

        update_state(bufnr, new_state)

        --exit_code 143 means SIGTERM
        if
            next(state(bufnr).testResults[1].assertionResults) == nil
            and exit_code ~= 143
        then
            notify({
                "No test results for " .. vim.fn.expand("#" .. bufnr .. ":t"),
            }, vim.log.levels.ERROR)
        end

        for _, test in pairs(state(bufnr).testResults[1].assertionResults) do
            local severity = vim.diagnostic.severity.ERROR
            local message = "Test Failed"

            if test.status == TEST_RESULTS.SUCCESS then
                severity = vim.diagnostic.severity.INFO
                message = "Test Succeeded"
            elseif test.status == TEST_RESULTS.SKIPPED then
                severity = vim.diagnostic.severity.WARN
                message = "Test Skipped"
            end

            local root = get_root(bufnr)
            -- search line number with treesitter
            local query_output = vim.treesitter.parse_query(
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

            local line_number = function()
                for id, node in query_output:iter_captures(root, bufnr, 0, -1) do
                    local name = query_output.captures[id]
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

            local line = line_number()
            test["line"] = line

            local file_name = vim.fn.expand("#" .. bufnr)
            local sign_line = line + 1
            vim.fn.sign_place(
                file_name .. ":" .. sign_line,
                "continuous_tests", -- use default sign group so we can share animation instances.
                get_sign(test.status),
                bufnr,
                { lnum = sign_line, priority = 100 }
            )

            if severity ~= vim.diagnostic.severity.INFO then
                table.insert(state(bufnr).diagnostics, {
                    bufnr = bufnr,
                    lnum = line,
                    col = 0,
                    severity = severity,
                    source = "vitest",
                    message = message,
                    user_data = {},
                })
            end
        end

        local log_level = test_output.numFailedTests > 0
                and vim.log.levels.ERROR
            or vim.log.levels.INFO

        local message = test_output.numFailedTests > 0
                and test_output.numFailedTests .. " failing tests"
            or "All tests passed"

        notify(
            message,
            log_level,
            "Vitest " .. vim.fn.expand("#" .. bufnr .. ":t")
        )

        vim.diagnostic.set(ns, bufnr, state(bufnr).diagnostics, {})
    end
end

M.testing_dialog_message = function(--[[optional]]bufnr)
    if bufnr == nil then
        bufnr = 0
    end

    return { "This should be implemented" }
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

        local cwd = file_util.find_package_json_ancestor(
            vim.fn.expand("#" .. bufnr .. ":p")
        )

        local relative_cwd = file_util.find_package_json_ancestor(
            vim.fn.expand("#" .. bufnr .. ":f")
        )

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

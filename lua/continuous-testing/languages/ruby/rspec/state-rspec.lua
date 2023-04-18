---@class RspecBufferTestState: BufferTestState
---@field phase "pre_test" | "test" | "parse_test" | "post_test" Determine if rubocop or test finished/failed
---@field version string source Rspec
---@field seed number source Rspec

---@class RspecTestInstanceState: TestInstanceState
---@field description string source Rspec
---@field file_path string source Rspec
---@field line_number number source Rspec
---@field run_time string source Rspec
---@field exception {class: string, message: string, backtrace: string[]} source Rspec

local format = require("continuous-testing.utils.format")
local state = require("continuous-testing.state").get_state
local table_utils = require("continuous-testing.utils.table")
local treesitter_utils = require("continuous-testing.utils.treesitter")

local M = {}

M.generate_tests_state = function(bufnr, json_data)
    local buffer_test_state = state(bufnr)
    ---@cast buffer_test_state RspecBufferTestState

    buffer_test_state.version = json_data.version
    buffer_test_state.seed = json_data.seed

    for _, test in pairs(json_data.examples) do
        buffer_test_state.test_results[test.line_number] = state(bufnr).test_results[test.line_number]
            or {}
        table_utils.merge_table(
            buffer_test_state.test_results[test.line_number],
            test
        )
    end

    local log_level
    if json_data.summary.failure_count > 0 then
        log_level = vim.log.levels.ERROR
        buffer_test_state.telescope_status = "🚫"
    else
        log_level = vim.log.levels.INFO
        buffer_test_state.telescope_status = "✅"
    end

    buffer_test_state.summary_line = json_data.summary_line
    buffer_test_state.summary_log_level = log_level
end

---Generate failure message based on test_state
---@param bufnr number
---@param test_state RspecTestInstanceState | {}
---@return table
M.generate_failure_message = function(bufnr, test_state)
    local buffer_test_state = state(bufnr)
    ---@cast buffer_test_state RspecBufferTestState

    local message = {
        "Test: " .. test_state.description,
        "Location: " .. test_state.file_path .. ":" .. test_state.line_number,
        "Runtime: " .. test_state.run_time,
        "Seed: " .. buffer_test_state.seed,
        "",
        "Exception: " .. test_state.exception.class,
        "Message:",
    }

    -- Splitting on new lines because the message array cannot contain any when
    -- setting lines.
    for line in string.gmatch(test_state.exception.message, "[^\r\n]+") do
        table.insert(message, line)
    end

    table.insert(message, "")
    table.insert(message, "Backtrace:")

    if test_state.exception.backtrace ~= vim.NIL then
        for _, line in ipairs(test_state.exception.backtrace) do
            for backtrace in string.gmatch(line, "[^\r\n]+") do
                table.insert(message, backtrace)
            end
        end
    end

    return message
end

---Initialize state with phase `pre_test`
---Each test state
--- status = `pending`
--- title = description
---@param bufnr number
M.set_initial_state = function(bufnr)
    local buffer_test_state = state(bufnr)
    ---@cast buffer_test_state RspecBufferTestState

    local ts_query_tests = treesitter_utils.parse_query(
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
        if name == "title" then
            local title = treesitter_utils.get_node_text(node, bufnr)
            local range = { node:range() }
            buffer_test_state.test_results[range[1] + 1] = {
                status = "pending",
                title = title,
            }
            buffer_test_state.phase = "pre_test"
        end
    end
end

return M

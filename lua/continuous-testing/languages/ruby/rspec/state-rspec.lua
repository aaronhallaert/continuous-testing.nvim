-- [bufnr]: {
--     phase = "pre_test", "test", "parse_test", "post_test" // Determine if rubocop or test finished/failed
--     version = ...,                                        // -- source rspec
--     seed = ...,                                           // -- source rspec
--     test_results = {                                      // -- required ContinuousTesting
--         [line_number]: {
--             status = "passed", "failed", "pending",       // test result
--             description = ...,                            // -- source rspec
--             file_path = ...,                              // -- source rspec
--             line_number = ...,                            // -- source rspec
--             run_time = ...,                               // -- source rspec
--             exception = {                                 // -- source rspec
--                 class = ...,
--                 message = ...,
--                 backtrace = ...,
--             }
--         }
--     },
--     telescope_status = {},                                // -- required ContinuousTesting
--     diagnostics = {},                                     // -- required ContinuousTesting
--     summary_line = ...,                                   // -- required ContinuousTesting
--     summary_log_level = vim.log.levels.{},                // -- required ContinuousTesting
--     job = job_id                                          // -- required ContinuousTesting
-- }
--
--

local format = require("continuous-testing.utils.format")
local state = require("continuous-testing.state").get_state
local table_utils = require("continuous-testing.utils.table")

local M = {}

M.generate_tests_state = function(bufnr, json_data)
    state(bufnr).version = json_data.version
    state(bufnr).seed = json_data.seed

    for _, test in pairs(json_data.examples) do
        state(bufnr).test_results[test.line_number] = state(bufnr).test_results[test.line_number]
            or {}
        table_utils.merge_table(
            state(bufnr).test_results[test.line_number],
            test
        )
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

M.generate_failure_message = function(bufnr, test_state)
    local message = {
        "Test: " .. test_state.description,
        "Location: " .. test_state.file_path .. ":" .. test_state.line_number,
        "Runtime: " .. test_state.run_time,
        "Seed: " .. state(bufnr).seed,
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

-- Initialize state with phase `pre_test`
-- Each test state
--  status = `pending`
--  title = description
M.set_initial_state = function(bufnr)
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
        if name == "title" then
            local title = vim.treesitter.query.get_node_text(node, bufnr)
            local range = { node:range() }
            state(bufnr).test_results[range[1] + 1] =
                { status = "pending", title = title }
            state(bufnr).phase = "pre_test"
        end
    end
end

return M

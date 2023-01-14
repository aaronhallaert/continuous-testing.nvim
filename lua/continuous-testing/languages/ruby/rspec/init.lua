-- @author: https://github.com/aaronhallaert
-- @framework: rspec
---------------------------------------------

local config = require("continuous-testing.config")
local state = require("continuous-testing.state").get_state
local file_util = require("continuous-testing.utils.file")
local format = require("continuous-testing.utils.format")
local common = require("continuous-testing.languages.common")

--
-- rspec specific
--
local buffer_rspec =
    require("continuous-testing.languages.ruby.rspec.buffer-rspec")
local state_rspec =
    require("continuous-testing.languages.ruby.rspec.state-rspec")
local test_rspec = require("continuous-testing.languages.ruby.rspec.test-rspec")

local M = {}

M.command = function(bufnr, opts)
    opts = opts or { formatting = true }
    local path = file_util.relative_path(bufnr)

    if opts.lnum ~= nil then
        path = path .. ":" .. opts.lnum
    end

    local cmd = format.inject_file_to_test_command(
        config.get_config().ruby.test_cmd,
        path
    )
    if opts.formatting then
        return cmd .. " --format  json --no-fail-fast"
    else
        return cmd
    end
end

M.initialize_state = function(bufnr)
    state_rspec.set_initial_state(bufnr)
    buffer_rspec.set_start_signs(bufnr)
end

M.test_result_handler = function(bufnr, cmd)
    return test_rspec.run_test_file(bufnr, cmd)
end

M.testing_dialog_message = function(bufnr, line_position)
    local test_state = state(bufnr).test_results[line_position]
    if not test_state or test_state.status ~= common.TEST_RESULTS.FAILED then
        return
    end

    return state_rspec.generate_failure_message(bufnr, test_state)
end

return M

local file_util = require("continuous-testing.utils.file")

---@class TestInstanceState can be enhanced with wathever you want
---@field status "passed" | "failed" | "pending"
---@field title string

---@class DiagnosticStructure
---@field bufnr number
---@field lnum number
---@field col number
---@field severity string vim.log.levels
---@field source "ContinuousTesting",
---@field message string
---@field user_data table

---@class BufferMetaState
---@field autocmd number id of the 'OnSave' autocmd
---@field job number id of the test run
---@field testing_module any

---@class BufferTestState
---@field ct_meta BufferMetaState
---@field test_results table<number, TestInstanceState> indexed by line number
---@field diagnostics DiagnosticStructure[] @see diagnostic-structure
---@field summary_line string
---@field summary_log_level string vim.log.levels.{}
---@field telescope_status "🚫"| "✅" | "🏃" | ""

---@type table<number, BufferTestState>
local global_test_state = {}

local M = {}

---@param bufnr number
---@return BufferTestState
M.get_state = function(bufnr)
    return global_test_state[bufnr]
end

---@param bufnr number
---@param test_state BufferTestState
M.update_state = function(bufnr, test_state)
    global_test_state[bufnr] = test_state
end

---@param bufnr number
---@return boolean
M.is_attached = function(bufnr)
    for k, _ in pairs(global_test_state) do
        -- buffer is in keys and value is not nil
        if bufnr == k and global_test_state[k] ~= nil then
            return true
        end
    end

    return false
end

---@param bufnr number
M.detach = function(bufnr)
    global_test_state[bufnr] = nil
end

---@param bufnr number
M.attach = function(bufnr)
    global_test_state[bufnr] = {
        diagnostics = {},
        test_results = {},
        telescope_status = "",
        ct_meta = {},
    }
end

---@return {filename: string, telescope_status: string}]
M.attached_tests_telescope_status = function()
    local files = {}
    for k, _ in pairs(global_test_state) do
        local entry = {
            file_util.relative_path(k),
            M.get_state(k).telescope_status,
        }
        table.insert(files, entry)
    end

    return files
end

---@return {bufnr: number, filename: string, line_number: number, test_description:string}[]
M.attached_tests_with_lines = function()
    local files = {}
    for k, _ in pairs(global_test_state) do
        for line, instance_state in pairs(M.get_state(k).test_results) do
            local file = {
                k,
                file_util.relative_path(k),
                line,
                instance_state.title or "-",
            }

            table.insert(files, file)
        end
    end

    return files
end

return M

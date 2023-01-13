local file_util = require("continuous-testing.utils.file")

-- {[bufnr] : { state }}
--   required in {state}
--      key: `tests`
--        value: table[line_number] =
--            {
--            status: "passed | failed | pending",
--            ... (whatever you want)
--            }
--      key: `diagnostics`
--        value: table =
--            { bufnr = bufnr,
--            lnum = line - 1,
--            col = 0,
--            severity = severity,
--            source = "ContinuousTesting",
--            message = message,
--            user_data = {} }
--      key: `summary_line`
--        value: string
--      key: `summary_log_level`
--        value: vim.log.levels.{}
--      key: `telescope_status`
--        value: 🚫 | ✅
--      key: `job`
--        value: jobid
local global_test_state = {}

local M = {}

M.get_state = function(bufnr)
    return global_test_state[bufnr]
end

M.update_state = function(bufnr, test_state)
    global_test_state[bufnr] = test_state
end

M.is_attached = function(bufnr)
    for k, _ in pairs(global_test_state) do
        -- buffer is in keys and value is not nil
        if bufnr == k and global_test_state[k] ~= nil then
            return true
        end
    end

    return false
end

M.detach = function(bufnr)
    global_test_state[bufnr] = nil
end

M.attach = function(bufnr)
    global_test_state[bufnr] = {}
end

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

-- @return table [{filename, line_number, test_description}]
M.attached_tests_with_lines = function()
    local files = {}
    for k, _ in pairs(global_test_state) do
        for line, instance_state in pairs(M.get_state(k).tests) do
            local file = {
                k,
                file_util.relative_path(k),
                line,
                instance_state.title,
            }
            table.insert(files, file)
        end
    end

    return files
end

return M

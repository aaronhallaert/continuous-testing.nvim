-- {[bufnr] : { ...state... }}
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

M.attached_tests = function()
    local files = {}
    for k, _ in pairs(global_test_state) do
        local file = vim.fn.expand("#" .. k .. ":f")
        table.insert(files, file)
    end

    return files
end

return M

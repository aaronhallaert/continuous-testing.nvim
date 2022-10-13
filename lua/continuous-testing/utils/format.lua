local M = {}

M.inject_file_to_test_command = function(test_command, file)
    return test_command:gsub("%%file", file)
end

return M

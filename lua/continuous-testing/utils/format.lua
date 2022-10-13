local M = {}

M.inject_file_to_test_command = function(test_command, file)
    return test_command:gsub("%%file", file)
end

M.get_treesitter_root = function(bufnr, filetype)
    local parser = vim.treesitter.get_parser(bufnr, filetype, {})
    local tree = parser:parse()[1]
    return tree:root()
end

M.split = function(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

return M

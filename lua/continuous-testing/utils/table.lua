local M = {}

M.deepcopy_table = function(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[M.deepcopy_table(orig_key)] = M.deepcopy_table(orig_value)
        end
        setmetatable(copy, M.deepcopy_table(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

return M

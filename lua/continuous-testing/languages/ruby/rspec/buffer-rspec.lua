local common = require("continuous-testing.languages.common")
local format = require("continuous-testing.utils.format")
local treesitter_utils = require("continuous-testing.utils.treesitter")

local M = {}

M.set_start_signs = function(bufnr)
    local ts_query_tests = treesitter_utils.parse_query(
        "ruby",
        [[
        (call
            method: (identifier) @id (#match? @id "^(it|xit)$")
        )
    ]]
    )

    local root = format.get_treesitter_root(bufnr, "ruby")

    for id, node in ts_query_tests:iter_captures(root, bufnr, 0, -1) do
        local name = ts_query_tests.captures[id]
        if name == "id" then
            -- {start row, start col, end row, end col}
            local range = { node:range() }
            common.place_start_sign(bufnr, range[1] + 1)
        end
    end
end

return M

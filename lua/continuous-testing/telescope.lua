local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local format = require("continuous-testing.utils.format")

local M = {}
M.open_attached_tests = function()
    -- local previewers = require("telescope.previewers")
    local pickers = require("telescope.pickers")
    local sorters = require("telescope.sorters")
    local finders = require("telescope.finders")

    local tests = require("continuous-testing.state").attached_tests()
    pickers
        .new({
            results_title = "Attached tests",
            finder = finders.new_table(tests),
            sorter = sorters.get_fuzzy_file(),
            attach_mappings = function(_, map)
                map("i", "<CR>", function(prompt_bufnr)
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    local file = format.split(selection.value, " ")[1]
                    vim.cmd(":edit " .. file)
                end)
                return true
            end,
        })
        :find()
end

return M

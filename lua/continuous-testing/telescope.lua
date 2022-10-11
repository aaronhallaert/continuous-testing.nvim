local M = {}
M.open_attached_tests = function()
    local previewers = require("telescope.previewers")
    local pickers = require("telescope.pickers")
    local sorters = require("telescope.sorters")
    local finders = require("telescope.finders")

    local tests = require("continuous-testing.state").attached_tests()
    pickers
        .new({
            results_title = "Attached tests",
            finder = finders.new_table(tests),
            sorter = sorters.get_fuzzy_file(),
        })
        :find()
end

return M

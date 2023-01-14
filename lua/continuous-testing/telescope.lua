local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local state = require("continuous-testing.state").get_state

local M = {}
M.open_attached_tests = function()
    local pickers = require("telescope.pickers")
    local sorters = require("telescope.sorters")
    local finders = require("telescope.finders")
    local previewers = require("telescope.previewers")

    local tests =
        require("continuous-testing.state").attached_tests_telescope_status()
    pickers
        .new({
            results_title = "Attached tests",
            finder = finders.new_table({
                results = tests,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry[2] .. " " .. entry[1],
                        ordinal = entry[1],
                        filename = entry[1],
                    }
                end,
            }),
            sorter = sorters.get_fuzzy_file(),
            previewer = previewers.vim_buffer_cat.new({ title = "Test" }),
            attach_mappings = function(_, map)
                map("i", "<CR>", function(prompt_bufnr)
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    vim.cmd(":edit " .. selection.filename)
                end)
                return true
            end,
        })
        :find()
end

M.open_attached_test_instances = function()
    local pickers = require("telescope.pickers")
    local sorters = require("telescope.sorters")
    local finders = require("telescope.finders")
    local previewers = require("telescope.previewers")

    local tests =
        require("continuous-testing.state").attached_tests_with_lines()

    pickers
        .new({
            title = "Attached test instances",
            finder = finders.new_table({
                results = tests,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry[2]
                            .. ":"
                            .. entry[3]
                            .. " "
                            .. entry[4],
                        ordinal = entry[4],
                        lnum = entry[3],
                        bufnr = entry[1],
                        filename = entry[2],
                        preview_title = entry[4],
                    }
                end,
            }),
            sorter = sorters.get_fuzzy_file(),
            previewer = previewers.vim_buffer_vimgrep.new({ title = "Test" }),
            attach_mappings = function(_, map)
                map("i", "<CR>", function(prompt_bufnr)
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()

                    local formatted_cmd =
                        state(selection.bufnr).ct_meta.testing_module.command(
                            selection.bufnr,
                            { formatting = false, lnum = selection.lnum }
                        )
                    vim.cmd(":term " .. formatted_cmd)
                end)
                return true
            end,
        })
        :find()
end

return M

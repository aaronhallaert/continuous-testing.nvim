local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local format = require("continuous-testing.utils.format")

local M = {}
M.open_attached_tests = function()
    -- local previewers = require("telescope.previewers")
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
                    local file = selection[1]
                    print("File: " .. file)
                    vim.cmd(":edit " .. file)
                end)
                return true
            end,
        })
        :find()
end

M.open_attached_test_instances = function(cmd)
    -- local previewers = require("telescope.previewers")
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
                        display = entry[1]
                            .. ":"
                            .. entry[2]
                            .. " "
                            .. entry[3],
                        ordinal = entry[3],
                        lnum = entry[2],
                        filename = entry[1],
                        preview_title = entry[3],
                    }
                end,
            }),
            sorter = sorters.get_fuzzy_file(),
            previewer = previewers.vim_buffer_vimgrep.new({ title = "Test" }),
            attach_mappings = function(_, map)
                map("i", "<CR>", function(prompt_bufnr)
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    local file = format.split(selection.value, " ")[1]
                    local formatted_cmd =
                        format.inject_file_to_test_command(cmd, file)
                    vim.cmd(":term " .. formatted_cmd)
                end)
                return true
            end,
        })
        :find()
end

return M

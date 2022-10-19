local table_util = require("continuous-testing.utils.table")
local M = {}

local config = {}

local DEFAULT_CONFIG = {
    notify = false,
    run_tests_on_setup = true,
}

local set_default_values = function()
    for key, value in ipairs(DEFAULT_CONFIG) do
        if config[key] == nil then
            config[key] = value
        end
    end
end

M.set_user_specific_config = function(user_config)
    config = user_config

    set_default_values()
end

M.get_config = function()
    local result = {}
    -- start with default config
    local default_c = table_util.deepcopy_table(DEFAULT_CONFIG)
    table_util.merge_table(result, default_c)

    -- merge the framework configs (general and project)
    local framework_config = {}

    local general_framework_config =
        table_util.deepcopy_table(config.framework_setup)
    if general_framework_config ~= nil then
        table_util.merge_table(framework_config, general_framework_config)
    end

    local project_framework_config =
        table_util.deepcopy_table(config.project_override[vim.fn.getcwd()])
    if project_framework_config ~= nil then
        table_util.merge_table(framework_config, project_framework_config)
    end
    table_util.merge_table(result, framework_config)

    -- merge all other variables and remove the framework and project_override
    table_util.merge_table(result, config)

    result["framework_setup"] = nil
    result["project_override"] = nil

    return result
end

return M

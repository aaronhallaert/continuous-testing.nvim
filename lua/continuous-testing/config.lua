local utils = require("continuous-testing.utils")
local M = {}

local config = {}

local DEFAULT_CONFIG = {
    notify = false,
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
    local framework_config = utils.deepcopy_table(config.framework_setup)

    local project_framework_config =
        utils.deepcopy_table(config.project_override[vim.fn.getcwd()])

    if project_framework_config ~= nil then
        for k, v in pairs(project_framework_config) do
            framework_config[k] = v
        end
    end

    return framework_config
end

return M

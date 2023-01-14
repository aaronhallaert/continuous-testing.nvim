local table_util = require("continuous-testing.utils.table")

---@alias FrameworkSetup table<"ruby" | "javascript", FrameworkConfig>

local M = {}

---@class CTConfig
---@field notify boolean
---@field run_tests_on_setup boolean
---@field frameworks FrameworkConfig
local continuous_testing_config = {}

---@type CTConfig
local DEFAULT_CONFIG = {
    notify = false,
    run_tests_on_setup = true,
}

---Apply default values to the passed config
---@param config CTConfig
local set_default_values = function(config)
    for key, value in pairs(DEFAULT_CONFIG) do
        if config[key] == nil then
            config[key] = value
        end
    end
end

---@param user_config CTInputConfig
---@return CTConfig
local parse_user_config = function(user_config)
    local result = {} ---@type CTConfig

    local framework_config = {} --@type FrameworkConfig
    local general_framework_config =
        table_util.deepcopy_table(user_config.framework_setup)
    if general_framework_config ~= nil then
        table_util.merge_table(framework_config, general_framework_config)
    end

    -- determine the key of the project
    local key = "unknown"
    local current_dir = vim.fn.getcwd()
    for path, _ in pairs(user_config.project_override) do
        -- Paths can contain lua magic character '-'
        -- String find does not work with this hyphen, therefore they are subbed
        if
            string.find(
                string.gsub(current_dir, "%-", ""),
                string.gsub(path, "%-", "")
            )
        then
            key = path
            break
        end
    end

    local project_framework_config =
        table_util.deepcopy_table(user_config.project_override[key])
    if project_framework_config ~= nil then
        table_util.merge_table(framework_config, project_framework_config)
    end
    table_util.merge_table(result, framework_config)

    user_config["framework_setup"] = nil
    user_config["project_override"] = nil

    -- merge all other variables and remove the framework and project_override
    table_util.merge_table(result, user_config)

    return result
end

---@param user_config CTInputConfig
M.set_config = function(user_config)
    continuous_testing_config = parse_user_config(user_config)
    set_default_values(continuous_testing_config)
end

--@return CTConfig
M.get_config = function()
    return table_util.deepcopy_table(continuous_testing_config)
end

return M

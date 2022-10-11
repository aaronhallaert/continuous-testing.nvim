local M = {}

local config = {}

local DEFAULT_CONFIG = {
    notifies = false,
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
    return config
end

return M

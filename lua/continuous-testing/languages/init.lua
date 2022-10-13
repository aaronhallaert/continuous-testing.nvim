local config_helper = require("continuous-testing.config")
local notify = require("continuous-testing.utils.notify")

local M = {}

local FILE_TYPES = {
    rb = "ruby",
    ts = "javascript",
    js = "javascript",
    tsx = "javascript",
    jsx = "javascript",
}

local resolve_testing_module = function(language, test_tool)
    return require(
        "continuous-testing.languages." .. language .. "." .. test_tool
    )
end

local module_exists = function(language, test_tool)
    local module = "continuous-testing.languages."
        .. language
        .. "."
        .. test_tool

    if package.loaded[module] then
        return true
    else
        for _, searcher in ipairs(package.searchers or package.loaders) do
            local loader = searcher(module)
            if type(loader) == "function" then
                package.preload[module] = loader
                return true
            end
        end
        return false
    end
end

M.resolve_testing_module_by_file_type = function(filetype)
    local config = config_helper.get_config()
    local language = FILE_TYPES[filetype]
    if language == nil then
        notify(
            "Language for filetype: " .. filetype .. "not supported",
            vim.log.levels.ERROR
        )
    end

    local test_tool = config[language].test_tool
    if test_tool == nil then
        notify(
            "No testing tool specified for " .. language,
            vim.log.levels.ERROR
        )
        return
    end

    if not module_exists(language, test_tool) then
        notify(
            test_tool .. " is not supported for " .. language,
            vim.log.levels.ERROR
        )
        return
    end

    return resolve_testing_module(language, test_tool)
end

return M

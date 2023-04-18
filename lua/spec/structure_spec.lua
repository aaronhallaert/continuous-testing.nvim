local scan = require("plenary.scandir")
local Path = require("plenary.path")

local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local supported_modules = function()
    local t = {}
    local dirs = scan.scan_dir(
        "./lua/continuous-testing/languages",
        { depth = 1, add_dirs = true }
    )

    for _, file in pairs(dirs) do
        if Path:new(file):is_dir() then
            local supported_language_paths =
                scan.scan_dir(file, { depth = 1, add_dirs = true })

            for _, lang in pairs(supported_language_paths) do
                local lang_path = Path:new(lang)
                local lang_split = split(lang_path.filename, "/")

                local framework =
                    string.gsub(lang_split[#lang_split], ".lua", "")

                local parent_split = split(lang_path:parent().filename, "/")
                local language = parent_split[#parent_split]

                local module = language .. "." .. framework
                table.insert(t, module)
            end
        end
    end

    return t
end

describe("structure of supported language implementations ", function()
    it("checks if test_result_handler exists", function()
        for _, module in pairs(supported_modules()) do
            assert.not_equals(
                require("continuous-testing.languages." .. module).test_result_handler,
                nil
            )
        end
    end)

    it("checks if command exists", function()
        for _, module in pairs(supported_modules()) do
            assert.not_equals(
                require("continuous-testing.languages." .. module).command,
                nil
            )
        end
    end)

    it("checks if testing_dialog_message exists", function()
        for _, module in pairs(supported_modules()) do
            assert.not_equals(
                require("continuous-testing.languages." .. module).testing_dialog_message,
                nil
            )
        end
    end)

    it("checks if initialize_state exists", function()
        for _, module in pairs(supported_modules()) do
            assert.not_equals(
                require("continuous-testing.languages." .. module).initialize_state,
                nil
            )
        end
    end)
end)

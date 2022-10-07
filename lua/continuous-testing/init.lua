local commands = require("continuous-testing.commands")

local M = {}

M.setup = function(config)
    require("continuous-testing.config").set_user_specific_config(config or {})

    commands.setup()
end

return M

local NOTIFY_TITLE = "ContinuousTesting.nvim"

return function(content, log_level)
    local config = require("continuous-testing.config").get_config()

    if not config.notify then
        return
    end

    vim.notify(content, log_level, { title = NOTIFY_TITLE })
end

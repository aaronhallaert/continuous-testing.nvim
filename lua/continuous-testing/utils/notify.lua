local NOTIFY_TITLE = "ContinuousTesting.nvim"

return function(
    content,
    log_level,
    --[[optional]]
    title
)
    if title == nil or title == "" then
        title = NOTIFY_TITLE
    end

    local config = require("continuous-testing.config").get_config()
    if not config.notify then
        return
    end

    vim.notify(content, log_level, { title = title })
end

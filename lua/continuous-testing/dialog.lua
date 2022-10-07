local M = {}

M.open = function(content)
    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")

    local win_height = math.ceil(height * 0.8 - 4)
    local win_width = math.ceil(width * 0.8)

    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 2)

    local opts = {
        style = "minimal",
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col,
        border = "rounded",
    }

    local buffer = vim.api.nvim_create_buf(false, "nomodified")
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, content)
    vim.api.nvim_open_win(buffer, true, opts)
end

return M

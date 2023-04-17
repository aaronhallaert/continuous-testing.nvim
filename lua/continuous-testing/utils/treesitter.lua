local M = {}

M.get_node_text = vim.treesitter.get_node_text
    or vim.treesitter.query.get_node_text

M.parse_query = vim.treesitter.query.parse or vim.treesitter.parse_query

return M

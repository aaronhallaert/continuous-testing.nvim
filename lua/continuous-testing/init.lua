local M = {}

M.setup = function(config)
    require("continuous-testing.ruby_rspec").setup {test_command = config.test_command.ruby_rspec}
end

return M

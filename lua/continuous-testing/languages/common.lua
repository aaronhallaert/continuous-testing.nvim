local update_state = require("continuous-testing.state").update_state

local M = {}

M.ns = vim.api.nvim_create_namespace("ContinuousTesting")

M.get_sign = function(test_result, test_results)
    local sign_name
    if test_result == test_results.SUCCESS then
        sign_name = "test_success"
    elseif test_result == test_results.FAILED then
        sign_name = "test_failure"
    elseif test_result == test_results.SKIPPED then
        sign_name = "test_skipped"
    else
        sign_name = "test_other"
    end
    return sign_name
end

M.clear_test_results = function(bufnr)
    vim.diagnostic.reset(M.ns, bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
    vim.fn.sign_unplace("continuous_tests", { buffer = bufnr })

    update_state(
        bufnr,
        { diagnostics = {}, tests = {}, telescope_status = "🏃" }
    )
end

return M

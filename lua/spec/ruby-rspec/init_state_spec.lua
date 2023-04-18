local rspec_state =
    require("continuous-testing.languages.ruby.rspec.state-rspec")
local state = require("continuous-testing.state")

local basic_rspec_test_lines = {
    "describe 'rspec initial state' do",
    "  it 'sets initial state' do",
    "    expect(true).to eq(true)",
    "  end",
    "end",
}

describe("rspec initial state", function()
    it("sets initial state", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, basic_rspec_test_lines)

        state.attach(bufnr)
        -- Execute the function
        rspec_state.set_initial_state(bufnr)

        assert.are.same(state.get_state(bufnr)["test_results"], {
            [2] = {
                status = "pending",
                title = "sets initial state",
            },
        })

        assert.are.same(state.get_state(bufnr)["phase"], "pre_test")
    end)
end)

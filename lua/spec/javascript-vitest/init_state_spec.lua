local vitest_state = require("continuous-testing.languages.javascript.vitest")
local state = require("continuous-testing.state")

local basic_vitest_test_lines = {
    "import App from './App';",
    "",
    "describe('App', () => {",
    "it('should render', () => {",
    "const app = render(<App />);",
    "expect(app).toBeTruthy();",
    "expect(app.getByTestId('main')).toBeTruthy();",
    "});",
    "});",
}

describe("rspec initial state", function()
    it("sets initial state", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, basic_vitest_test_lines)

        state.attach(bufnr)
        -- Execute the function
        vitest_state.initialize_state(bufnr)

        assert.are.same(state.get_state(bufnr)["test_results"], {
            [4] = {
                title = "should render",
            },
        })
    end)
end)

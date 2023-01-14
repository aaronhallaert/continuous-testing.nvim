------------
-- CONFIG --
------------

---@class FrameworkConfig
---@field test_tool string
---@field test_cmd string
---@field root_pattern string

---@class CTInputConfig
---@field notify boolean
---@field run_tests_on_setup boolean
---@field framework_setup FrameworkSetup
---@field project_override table<string, FrameworkSetup>

---@alias SupportedFrameworks "rspec" | "vitest"
---@alias TestState "passed" | "failed" | "pending"

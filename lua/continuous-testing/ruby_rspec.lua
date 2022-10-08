local M = {}

local TEST_STATES =
    { SUCCESS = "passed", FAILED = "failed", SKIPPED = "pending" }

local state = {}
local autocmd = nil

local ns = vim.api.nvim_create_namespace("ContinuousRubyTesting")
local group =
    vim.api.nvim_create_augroup("ContinuousRubyTesting", { clear = true })

local clear_test_results = function()
    vim.diagnostic.reset(ns, state.bufnr)
    vim.api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)

    state.version = nil
    state.seed = nil
    state.tests = {}
    state.diagnostics = {}
end

local notify_failure = function(test)
    local description = {
        "Test failed: " .. test.file_path .. ":" .. test.line_number - 1,
        -- "",
        -- "Exception: " .. test.exception.class,
        -- "",
        -- "Message: "
    }

    -- for line in string.gmatch(test.exception.message, "[^\r\n]+") do
    --     table.insert(description, line)
    -- end

    vim.notify(description, vim.log.levels.ERROR, { title = "RSpec" })
end

local on_exit_callback = function()
    for _, test in pairs(state.tests) do
        local severity = vim.diagnostic.severity.ERROR
        local message = "Test Failed"

        if test.status == TEST_STATES.SUCCESS then
            severity = vim.diagnostic.severity.INFO
            message = "Test Succeeded"
        elseif test.status == TEST_STATES.SKIPPED then
            severity = vim.diagnostic.severity.WARN
            message = "Test Skipped"
        end

        if test.status == TEST_STATES.FAILED then
            notify_failure(test)
        end

        table.insert(state.diagnostics, {
            bufnr = state.bufnr,
            lnum = test.line_number - 1,
            col = 0,
            severity = severity,
            source = "rspec",
            message = message,
            user_data = {},
        })
    end

    vim.diagnostic.set(ns, state.bufnr, state.diagnostics, {})
end

local buf_write_post_callback = function(bufnr, cmd)
    state = {
        bufnr = bufnr,
        version = nil,
        seed = nil,
        tests = {},
        diagnostics = {},
    }

    return function()
        clear_test_results()

        local append_data = function(_, data)
            if not data then
                return
            end

            for _, line in ipairs(data) do
                if not string.find(line, "{") then
                    return
                end

                local decoded = vim.json.decode(line)

                state.version = decoded.version
                state.seed = decoded.seed

                for _, test in pairs(decoded.examples) do
                    state.tests[test.file_path .. ":" .. test.line_number] =
                        test

                    local text = { "❓" }
                    if test.status == TEST_STATES.SUCCESS then
                        text = { "✅" }
                    elseif test.status == TEST_STATES.FAILED then
                        text = { "❌" }
                    elseif test.status == TEST_STATES.SKIPPED then
                        text = { "⏭️" }
                    end

                    vim.api.nvim_buf_set_extmark(
                        state.bufnr,
                        ns,
                        test.line_number - 1,
                        0,
                        { virt_text = { text } }
                    )
                end
            end
        end

        vim.fn.jobstart(cmd, {
            stdout_buffered = true,
            on_stdout = append_data,
            on_stderr = append_data,
            on_exit = on_exit_callback,
        })
    end
end

local testing_dialog = function()
    local test_key = "./" .. vim.fn.expand("%") .. ":" .. vim.fn.line(".")

    local test = state.tests[test_key]
    if not test or test.status ~= TEST_STATES.FAILED then
        return
    end

    local message = {
        "Test: " .. test.description,
        "Location: " .. test.file_path .. ":" .. test.line_number,
        "Runtime: " .. test.run_time,
        "Seed: " .. state.seed,
        "",
        "Exception: " .. test.exception.class,
        "Message:",
    }

    -- Splitting on new lines because the message array cannot contain any when
    -- setting lines.
    for line in string.gmatch(test.exception.message, "[^\r\n]+") do
        table.insert(message, line)
    end

    table.insert(message, "")
    table.insert(message, "Backtrace:")

    if test.exception.backtrace ~= vim.NIL then
        for _, line in ipairs(test.exception.backtrace) do
            for backtrace in string.gmatch(line, "[^\r\n]+") do
                table.insert(message, backtrace)
            end
        end
    end

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
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, message)
    vim.api.nvim_open_win(buffer, true, opts)
end

local attach_autocmd_to_buffer = function(bufnr, pattern, cmd)
    vim.api.nvim_buf_create_user_command(
        bufnr,
        "ContinuousRubyTestingDialog",
        testing_dialog,
        {}
    )

    vim.api.nvim_buf_create_user_command(
        bufnr,
        "ContinuousRubyTestingFailures",
        function()
            vim.diagnostic.setqflist({
                ns = ns,
                open = true,
                title = "Failed tests:",
                severity = vim.diagnostic.severity.ERROR,
            })
        end,
        {}
    )

    vim.api.nvim_create_user_command("StopContinuousRubyTesting", function()
        state.active = false

        vim.api.nvim_del_autocmd(autocmd)
        vim.api.nvim_del_user_command("StopContinuousRubyTesting")
        vim.api.nvim_buf_del_user_command(bufnr, "ContinuousRubyTestingDialog")
        vim.api.nvim_buf_del_user_command(
            bufnr,
            "ContinuousRubyTestingFailures"
        )

        clear_test_results()
    end, {})

    autocmd = vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        pattern = pattern,
        callback = buf_write_post_callback(bufnr, cmd),
    })

    state.active = true
end

local inject_file_to_test_command = function(test_command, file)
    return test_command:gsub("%%file", file)
end

M.setup = function(config)
    local test_command = config.test_command

    vim.api.nvim_create_user_command("ContinuousRubyTesting", function()
        if state.active then
            vim.notify(
                "ContinuousRubyTesting is already active",
                vim.log.levels.INFO
            )
            return
        end

        local bufnr = vim.api.nvim_get_current_buf()
        local filename = vim.fn.expand("%")

        attach_autocmd_to_buffer(
            bufnr,
            "*.rb",
            inject_file_to_test_command(test_command, filename)
        )
    end, {})
end

return M

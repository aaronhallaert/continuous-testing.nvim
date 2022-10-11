# continuous-testing.nvim

## Description

Run tests async on save, add to diagnostics, get notified on failures.

### Screenshots

![Test Failure](./media/test_failure.png)
![Test Failure Dialog](./media/test_failure_dialog.png)
![Test Success](./media/test_success.png)

## Installation

### Packer

```lua
return require('packer').startup(function(use)
    use 'aaronhallaert/continuous-testing.nvim'
end)
```

### Dependencies

- [nvim-notify](https://github.com/rcarriga/nvim-notify)

### Config

```lua
-- %file will be replace with the test file
require("continuous-testing").setup {
    notify = true -- The default is false
    ruby = {
        test_tool = "rspec",
        test_cmd = "bundle exec spring rspec %file --format json --no-fail-fast"
    }
}
```

## Usage

| Command                       | Usage                                              | Behaviour                                     |
| ----------------------------- | ---------------------------------------------------| --------------------------------------------- |
| ContinuousTesting             | When current buffer is a test file                 | Add current buffer to start tests on save     |
| ContinuousTestingDialog       | On line of failure                                 | Show output of failed test in floating window |
| StopContinuousTesting         | Anywhere in vim when continuous testing is enabled | Stops the continuous testing                  |

## TODO

- [ ] Create default test command for a language
- [ ] Ability to override test command based on project (folder)
- [x] Add different languages (change to general command `ContinuousTesting` instead of `ContinuousRubyTesting`)
- [x] Add branch protection to github project
- [x] Add github actions: linters, tests
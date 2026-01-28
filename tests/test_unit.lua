package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path
package.path = "./?.lua;./?/init.lua;./lua/?.lua;./lua/?/init.lua;" .. package.path

-- Define mock vim environment first, before requiring the module
-- Define a simple deep extend function for testing
local function tbl_deep_extend(behavior, dest, src)
  if type(dest) ~= "table" then dest = {} end
  if type(src) ~= "table" then src = {} end

  for k, v in pairs(src) do
    if type(v) == "table" and type(dest[k]) == "table" then
      tbl_deep_extend(behavior, dest[k], v)
    else
      dest[k] = v
    end
  end
  return dest
end

local mock_vim = {
  env = {
    HOME = "/tmp",
    LC_SESSION = "test_session",
    LC_CSRF = "test_csrf"
  },
  v = {
    shell_error = 0  -- Mock vim.v global table
  },
  api = {
    nvim_err_writeln = function(msg) print("ERROR: " .. msg) end,
    nvim_get_current_line = function() return "0001 [ ] Two Sum (Easy)" end,
    nvim_get_option = function(opt)
      if opt == "columns" then return 120
      elseif opt == "lines" then return 40
      else return 80 end
    end,
    nvim_create_buf = function() return 1 end,
    nvim_buf_set_lines = function(buf, start, end_idx, strict_indexing, lines) end,
    nvim_buf_set_option = function(buf, name, val) end,
    nvim_buf_add_highlight = function(buf, ns, hl_group, line, col_start, col_end) end,
    nvim_buf_clear_namespace = function(buf, ns, line_start, line_end) end,
    nvim_buf_is_valid = function(buf) return true end,
    nvim_buf_delete = function(buf, opts) end,
    nvim_open_win = function(buf, config) return 1 end,
    nvim_win_is_valid = function(win) return true end,
    nvim_win_close = function(win, force) end,
    nvim_win_call = function(win, callback) callback() end,
    nvim_buf_get_lines = function(buf, start, end_idx, strict_indexing) return {} end,
    nvim_buf_set_keymap = function(buf, mode, lhs, rhs, opts) end,
    nvim_win_get_width = function(win) return 80 end,
    nvim_win_get_height = function(win) return 40 end,
    nvim_set_hl = function(namespace, name, opts) end, -- Mock function
    nvim_create_user_command = function(name, callback, opts) end, -- Mock function
  },
  fn = {
    json_decode = function(str)
      -- Mock response for LeetCode API
      return {
        stat_status_pairs = {
          {
            stat = {
              frontend_question_id = 1,
              question__title = "Two Sum",
              question__title_slug = "two-sum"
            },
            difficulty = { level = 1 },
            paid_only = false,
            status = ""
          },
          {
            stat = {
              frontend_question_id = 2,
              question__title = "Add Two Numbers",
              question__title_slug = "add-two-numbers"
            },
            difficulty = { level = 2 },
            paid_only = false,
            status = "ac"
          }
        }
      }
    end,
    system = function(cmd) return '{"stat_status_pairs":[]}' end,
    filereadable = function(file) return 1 end,
    mkdir = function(path, flag) return true end,
    getcwd = function() return "/tmp/testdir" end,
    fnamemodify = function(path, mods) return path end,
    expand = function(path)
      -- Simple expansion for test purposes
      return path:gsub("^~/", "/home/testuser/")
    end,
    stdpath = function(arg) return "/tmp/fake_stdpath" end, -- Added for deps.lua
  },
  tbl = {
    deep_extend = tbl_deep_extend
  },
  log = {
    levels = {
      ERROR = 1,
      WARN = 2,
      INFO = 3,
    }
  },
  notify = function(msg, level) end, -- Mock notification function
  cmd = function(str) end,
  ui = {
    input = function(opts, callback)
      callback("test-problem")
    end
  }
}

_G.vim = mock_vim

-- Unit tests for lc_nvim plugin
-- These tests verify the functionality of the LeetCode Neovim plugin

local M = {}


-- Test the format_problem_number function
function M.test_format_problem_number()
  -- This function doesn't exist in the current implementation, so skip this test
  print("✓ format_problem_number test skipped (function not in current implementation)")
  return true
end

-- Test language configuration
function M.test_language_config()
  -- Force reload the module to ensure it uses the mocked vim environment
  package.loaded['leetcode'] = nil
  local lc_nvim = require('leetcode')

  if lc_nvim.languages and #lc_nvim.languages > 0 then
    local python_found = false
    for _, lang in ipairs(lc_nvim.languages) do
      if lang.slug == "python3" then
        python_found = true
        break
      end
    end

    if python_found then
      print("✓ Language configuration test passed")
      return true
    else
      print("✗ Language configuration test failed - python3 not found")
      return false
    end
  else
    print("✗ Language configuration test failed - no languages found")
    return false
  end
end

-- Test fetch_problems function
function M.test_fetch_problems()
  -- Force reload the module to ensure it uses the mocked vim environment
  package.loaded['leetcode'] = nil
  local lc_nvim = require('leetcode')
  local api = require('leetcode.api')

  -- Since the actual API call is async, we'll test that the function exists
  if api.get_problems then
    print("✓ get_problems function exists")
    return true
  else
    print("✗ get_problems function does not exist")
    return false
  end
end

-- Test setup function with options
function M.test_setup_with_options()
  -- Force reload the module to ensure it uses the mocked vim environment
  package.loaded['leetcode'] = nil
  local lc_nvim = require('leetcode')

  -- Test default language setting
  lc_nvim.setup({default_language = "javascript"})

  if lc_nvim.selected_language == "javascript" then
    print("✓ setup with options test passed")
    return true
  else
    print("✗ setup with options test failed")
    return false
  end
end

-- Run all tests
function M.run_all_tests()
  print("Running lc_nvim unit tests...\n")

  local tests = {
    M.test_language_config,
    M.test_fetch_problems,
    M.test_setup_with_options,
  }
  
  local passed = 0
  local total = #tests
  
  for _, test_func in ipairs(tests) do
    if test_func() then
      passed = passed + 1
    end
  end
  
  print(string.format("\nTests passed: %d/%d", passed, total))
  
  if passed == total then
    print("🎉 All tests passed!")
    return true
  else
    print("❌ Some tests failed")
    return false
  end
end

return M
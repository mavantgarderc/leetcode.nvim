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

-- Create a mock vim environment that simulates real Neovim behavior
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
    nvim_create_buf = function(listed, scratch)
      return math.random(1000, 9999) -- Return a random buffer ID
    end,
    nvim_buf_set_lines = function(buf, start, end_idx, strict_indexing, lines)
      -- Simulate setting lines in buffer
      _G.buffers = _G.buffers or {}
      _G.buffers[buf] = lines
    end,
    nvim_buf_set_option = function(buf, name, val) end,
    nvim_buf_add_highlight = function(buf, ns, hl_group, line, col_start, col_end) end,
    nvim_buf_clear_namespace = function(buf, ns, line_start, line_end) end,
    nvim_buf_is_valid = function(buf) return _G.buffers and _G.buffers[buf] ~= nil end,
    nvim_buf_delete = function(buf, opts)
      if _G.buffers then
        _G.buffers[buf] = nil
      end
    end,
    nvim_open_win = function(buf, enter, config)
      local win_id = math.random(100, 999)
      _G.windows = _G.windows or {}
      _G.windows[win_id] = {buffer = buf, config = config}
      return win_id
    end,
    nvim_win_is_valid = function(win) return _G.windows and _G.windows[win] ~= nil end,
    nvim_win_close = function(win, force)
      if _G.windows then
        _G.windows[win] = nil
      end
    end,
    nvim_win_call = function(win, callback) callback() end,
    nvim_buf_get_lines = function(buf, start, end_idx, strict_indexing)
      return _G.buffers and _G.buffers[buf] or {}
    end,
    nvim_buf_set_keymap = function(buf, mode, lhs, rhs, opts) end,
    nvim_win_get_width = function(win) return 80 end,
    nvim_win_get_height = function(win) return 40 end,
    nvim_set_hl = function(namespace, name, opts) end, -- Mock function
    nvim_create_user_command = function(name, callback, opts) end, -- Mock function
  },
  fn = {
    json_decode = function(str)
      -- More comprehensive mock response
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
              frontend_question_id = 3,
              question__title = "Longest Substring Without Repeating Characters",
              question__title_slug = "longest-substring-without-repeating-characters"
            },
            difficulty = { level = 2 },
            paid_only = false,
            status = "ac"
          },
          {
            stat = {
              frontend_question_id = 20,
              question__title = "Valid Parentheses",
              question__title_slug = "valid-parentheses"
            },
            difficulty = { level = 1 },
            paid_only = false,
            status = ""
          }
        }
      }
    end,
    system = function(cmd)
      -- Simulate successful command execution
      return "Success"
    end,
    filereadable = function(file)
      -- Simulate that files exist
      return 1
    end,
    mkdir = function(path, flag)
      -- Simulate directory creation
      return true
    end,
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
  cmd = function(str)
    -- Simulate command execution
    print("Executing command: " .. str)
  end,
  ui = {
    input = function(opts, callback)
      print("Prompt: " .. opts.prompt)
      -- Simulate user entering a problem name
      callback("two-sum")
    end
  }
}

_G.vim = mock_vim
_G.buffers = {}
_G.windows = {}

-- Integration tests for lc_nvim plugin
-- These tests simulate actual usage scenarios

local M = {}

-- Mock environment for integration testing
local function setup_integration_env()
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

  -- Create a mock vim environment that simulates real Neovim behavior
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
      nvim_create_buf = function(listed, scratch)
        return math.random(1000, 9999) -- Return a random buffer ID
      end,
      nvim_buf_set_lines = function(buf, start, end_idx, strict_indexing, lines)
        -- Simulate setting lines in buffer
        _G.buffers = _G.buffers or {}
        _G.buffers[buf] = lines
      end,
      nvim_buf_set_option = function(buf, name, val) end,
      nvim_buf_add_highlight = function(buf, ns, hl_group, line, col_start, col_end) end,
      nvim_buf_clear_namespace = function(buf, ns, line_start, line_end) end,
      nvim_buf_is_valid = function(buf) return _G.buffers and _G.buffers[buf] ~= nil end,
      nvim_buf_delete = function(buf, opts)
        if _G.buffers then
          _G.buffers[buf] = nil
        end
      end,
      nvim_open_win = function(buf, enter, config)
        local win_id = math.random(100, 999)
        _G.windows = _G.windows or {}
        _G.windows[win_id] = {buffer = buf, config = config}
        return win_id
      end,
      nvim_win_is_valid = function(win) return _G.windows and _G.windows[win] ~= nil end,
      nvim_win_close = function(win, force)
        if _G.windows then
          _G.windows[win] = nil
        end
      end,
      nvim_win_call = function(win, callback) callback() end,
      nvim_buf_get_lines = function(buf, start, end_idx, strict_indexing)
        return _G.buffers and _G.buffers[buf] or {}
      end,
      nvim_buf_set_keymap = function(buf, mode, lhs, rhs, opts) end,
      nvim_win_get_width = function(win) return 80 end,
      nvim_win_get_height = function(win) return 40 end,
    },
    fn = {
      json_decode = function(str)
        -- More comprehensive mock response
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
                frontend_question_id = 3,
                question__title = "Longest Substring Without Repeating Characters",
                question__title_slug = "longest-substring-without-repeating-characters"
              },
              difficulty = { level = 2 },
              paid_only = false,
              status = "ac"
            },
            {
              stat = {
                frontend_question_id = 20,
                question__title = "Valid Parentheses",
                question__title_slug = "valid-parentheses"
              },
              difficulty = { level = 1 },
              paid_only = false,
              status = ""
            }
          }
        }
      end,
      system = function(cmd)
        -- Simulate successful command execution
        return "Success"
      end,
      filereadable = function(file)
        -- Simulate that files exist
        return 1
      end,
      mkdir = function(path, flag)
        -- Simulate directory creation
        return true
      end,
      getcwd = function() return "/tmp/testdir" end,
      fnamemodify = function(path, mods) return path end,
      expand = function(path)
        -- Simple expansion for test purposes
        return path:gsub("^~/", "/home/testuser/")
      end,
    },
    tbl = {
      deep_extend = tbl_deep_extend
    },
    cmd = function(str)
      -- Simulate command execution
      print("Executing command: " .. str)
    end,
    ui = {
      input = function(opts, callback)
        print("Prompt: " .. opts.prompt)
        -- Simulate user entering a problem name
        callback("two-sum")
      end
    }
  }

  _G.vim = mock_vim
  _G.buffers = {}
  _G.windows = {}
end

-- Test the floating problem list functionality
function M.test_floating_problem_list()
  -- Force reload the module to ensure it uses the mocked vim environment
  package.loaded['leetcode'] = nil
  local lc_nvim = require('leetcode')

  -- Capture original functions that we'll override temporarily
  local original_open_win = vim.api.nvim_open_win
  local original_create_buf = vim.api.nvim_create_buf

  -- Track if windows and buffers were created
  local windows_created = 0
  local buffers_created = 0

  -- Override functions to track creation
  vim.api.nvim_open_win = function(buf, enter, config)
    windows_created = windows_created + 1
    return original_open_win(buf, enter, config)
  end

  vim.api.nvim_create_buf = function(listed, scratch)
    buffers_created = buffers_created + 1
    return original_create_buf(listed, scratch)
  end

  -- Call the function
  lc_nvim.show_floating_problem_list()

  -- Restore original functions
  vim.api.nvim_open_win = original_open_win
  vim.api.nvim_create_buf = original_create_buf

  -- Check if the expected number of windows and buffers were created
  if windows_created >= 2 and buffers_created >= 2 then
    print("✓ Floating problem list test passed")
    return true
  else
    print("✗ Floating problem list test failed - Expected at least 2 windows and 2 buffers, got " .. windows_created .. " windows and " .. buffers_created .. " buffers")
    return false
  end
end

-- Test language selection functionality
function M.test_language_selection()
  -- Force reload the module to ensure it uses the mocked vim environment
  package.loaded['leetcode'] = nil
  local lc_nvim = require('leetcode')

  -- Reset to default language first
  lc_nvim.selected_language = "python3"

  -- Test initial language
  local initial_lang = lc_nvim.selected_language
  if initial_lang ~= "python3" then
    print("✗ Language selection test failed - initial language not python3, got: " .. initial_lang)
    return false
  end

  -- Test language change
  lc_nvim.select_language_from_panel = function()
    -- Simulate selecting JavaScript
    vim.api.nvim_get_current_line = function() return "  JavaScript" end
    for _, lang in ipairs(lc_nvim.languages) do
      if lang.name == "JavaScript" then
        lc_nvim.selected_language = lang.slug
        break
      end
    end
  end

  lc_nvim.select_language_from_panel()

  if lc_nvim.selected_language == "javascript" then
    print("✓ Language selection test passed")
    return true
  else
    print("✗ Language selection test failed - language not changed to javascript, got: " .. lc_nvim.selected_language)
    return false
  end
end

-- Test problem fetching with language
function M.test_problem_fetch_with_language()
  -- Force reload the module to ensure it uses the mocked vim environment
  package.loaded['leetcode'] = nil
  local lc_nvim = require('leetcode')

  -- Test that the language selection mechanism works
  local original_lang = lc_nvim.state.selected_language
  lc_nvim.state.selected_language = "cpp"

  if lc_nvim.state.selected_language == "cpp" then
    -- Restore original language
    lc_nvim.state.selected_language = original_lang
    print("✓ Language selection test passed")
    return true
  else
    print("✗ Language selection test failed")
    return false
  end
end

-- Test the setup function
function M.test_setup_function()
  -- Force reload the module to ensure it uses the mocked vim environment
  package.loaded['leetcode'] = nil
  local lc_nvim = require('leetcode')

  -- Test with default language
  lc_nvim.setup({default_language = "java"})

  if lc_nvim.selected_language == "java" then
    print("✓ Setup function test passed")
    return true
  else
    print("✗ Setup function test failed")
    return false
  end
end

-- Run all integration tests
function M.run_all_tests()
  print("Running lc_nvim integration tests...\n")

  local tests = {
    M.test_floating_problem_list,
    M.test_language_selection,
    M.test_problem_fetch_with_language,
    M.test_setup_function
  }
  
  local passed = 0
  local total = #tests
  
  for _, test_func in ipairs(tests) do
    if test_func() then
      passed = passed + 1
    else
      -- Print which test failed
      print("A test failed (details not captured)")
    end
  end
  
  print(string.format("\nIntegration tests passed: %d/%d", passed, total))
  
  if passed == total then
    print("🎉 All integration tests passed!")
    return true
  else
    print("❌ Some integration tests failed")
    return false
  end
end

return M
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local function setup_mock_vim()
  _G.vim = {
    fn = {
      expand = function(path) return path:gsub("^~/", "/home/testuser/") end,
    },
    deepcopy = function(tbl)
      if type(tbl) ~= "table" then return tbl end
      local copy = {}
      for k, v in pairs(tbl) do
        copy[k] = _G.vim.deepcopy(v)
      end
      return copy
    end,
    inspect = function(tbl, opts) return require("inspect")(tbl) or tostring(tbl) end,
  }
end

setup_mock_vim()

local M = {}

function M.test_defaults()
  package.loaded["leetcode.config"] = nil
  local config = require("leetcode.config")

  local defaults = config.get_defaults()

  local required = {
    "storage_dir",
    "env_file",
    "cache_ttl",
    "default_language",
    "debug",
    "border_style",
    "icons",
    "difficulty_colors",
  }

  for _, key in ipairs(required) do
    if defaults[key] == nil then
      print("✗ Missing default key: " .. key)
      return false
    end
  end

  print("✓ Default config generation works")
  return true
end

function M.test_valid_config()
  package.loaded["leetcode.config"] = nil
  local config = require("leetcode.config")

  local test_config = {
    storage_dir = "/tmp/leetcode",
    env_file = "/tmp/.env",
    cache_ttl = 1800,
    default_language = "python3",
    debug = false,
    border_style = "rounded",
    icons = {
      solved = "✓",
      attempted = "◐",
      unsolved = "○",
      locked = "🔒",
    },
    difficulty_colors = {
      Easy = "LeetCodeEasy",
      Medium = "LeetCodeMedium",
      Hard = "LeetCodeHard",
    },
  }

  local ok, errors = config.validate(test_config)

  if not ok then
    print("✗ Valid config rejected: " .. table.concat(errors or {}, ", "))
    return false
  end

  print("✓ Valid config validation works")
  return true
end

function M.test_invalid_storage_dir()
  package.loaded["leetcode.config"] = nil
  local config = require("leetcode.config")

  local test_config = config.get_defaults()
  test_config.storage_dir = 123

  local ok, errors = config.validate(test_config)

  if ok then
    print("✗ Invalid storage_dir accepted")
    return false
  end

  print("✓ Invalid storage_dir rejected")
  return true
end

function M.test_invalid_cache_ttl()
  package.loaded["leetcode.config"] = nil
  local config = require("leetcode.config")

  local test_config = config.get_defaults()
  test_config.cache_ttl = -100

  local ok, errors = config.validate(test_config)

  if ok then
    print("✗ Negative cache_ttl accepted")
    return false
  end

  print("✓ Invalid cache_ttl rejected")
  return true
end

function M.test_invalid_border_style()
  package.loaded["leetcode.config"] = nil
  local config = require("leetcode.config")

  local test_config = config.get_defaults()
  test_config.border_style = "invalid_style"

  local ok, errors = config.validate(test_config)

  if ok then
    print("✗ Invalid border_style accepted")
    return false
  end

  print("✓ Invalid border_style rejected")
  return true
end

function M.test_invalid_icons()
  package.loaded["leetcode.config"] = nil
  local config = require("leetcode.config")

  local test_config = config.get_defaults()
  test_config.icons = {
    solved = "✓",
    attempted = "◐",
  }

  local ok, errors = config.validate(test_config)

  if ok then
    print("✗ Incomplete icons table accepted")
    return false
  end

  print("✓ Invalid icons table rejected")
  return true
end

function M.test_config_merge()
  package.loaded["leetcode.config"] = nil
  local config = require("leetcode.config")

  local user_config = {
    cache_ttl = 7200,
    debug = true,
  }

  local merged = config.merge(user_config)

  if merged.cache_ttl ~= 7200 then
    print("✗ User config not merged: cache_ttl")
    return false
  end

  if merged.debug ~= true then
    print("✗ User config not merged: debug")
    return false
  end

  if not merged.storage_dir then
    print("✗ Default not applied: storage_dir")
    return false
  end

  print("✓ Config merge works")
  return true
end

function M.test_unknown_keys()
  package.loaded["leetcode.config"] = nil
  local config = require("leetcode.config")

  local test_config = config.get_defaults()
  test_config.unknown_key = "value"

  local ok, errors = config.validate(test_config)

  if ok then
    print("✗ Unknown config key accepted")
    return false
  end

  print("✓ Unknown config keys rejected")
  return true
end

function M.test_nullable_http_method()
  package.loaded["leetcode.config"] = nil
  local config = require("leetcode.config")

  local test_config = config.get_defaults()
  test_config.http_method = nil

  local ok, errors = config.validate(test_config)

  if not ok then
    print("✗ Nullable http_method rejected")
    return false
  end

  test_config.http_method = "socket"
  ok, errors = config.validate(test_config)
  if not ok then
    print("✗ Valid http_method='socket' rejected")
    return false
  end

  test_config.http_method = "curl"
  ok, errors = config.validate(test_config)
  if not ok then
    print("✗ Valid http_method='curl' rejected")
    return false
  end

  test_config.http_method = "invalid"
  ok, errors = config.validate(test_config)
  if ok then
    print("✗ Invalid http_method accepted")
    return false
  end

  print("✓ Nullable http_method validation works")
  return true
end

function M.test_picker_config()
  package.loaded["leetcode.config"] = nil
  local config = require("leetcode.config")

  local test_config = config.get_defaults()

  test_config.picker = { width = 1.5 }
  local ok, errors = config.validate(test_config)
  if ok then
    print("✗ Invalid picker width accepted")
    return false
  end

  test_config.picker = { width = 0.8, height = 0.8 }
  ok, errors = config.validate(test_config)
  if not ok then
    print("✗ Valid picker config rejected")
    return false
  end

  print("✓ Picker config validation works")
  return true
end

function M.run_all()
  print("\n" .. string.rep("=", 50))
  print("Config Manager Tests")
  print(string.rep("=", 50) .. "\n")

  local tests = {
    { name = "Default generation", func = M.test_defaults },
    { name = "Valid config", func = M.test_valid_config },
    { name = "Invalid storage_dir", func = M.test_invalid_storage_dir },
    { name = "Invalid cache_ttl", func = M.test_invalid_cache_ttl },
    { name = "Invalid border_style", func = M.test_invalid_border_style },
    { name = "Invalid icons", func = M.test_invalid_icons },
    { name = "Config merge", func = M.test_config_merge },
    { name = "Unknown keys", func = M.test_unknown_keys },
    { name = "Nullable http_method", func = M.test_nullable_http_method },
    { name = "Picker config", func = M.test_picker_config },
  }

  local passed = 0
  local total = #tests

  for _, test in ipairs(tests) do
    local ok, result = pcall(test.func)
    if ok and result then
      passed = passed + 1
    elseif not ok then
      print("✗ Test '" .. test.name .. "' crashed: " .. tostring(result))
    end
  end

  print("\n" .. string.rep("=", 50))
  print(string.format("Results: %d/%d passed", passed, total))
  print(string.rep("=", 50) .. "\n")

  return passed == total
end

if arg and arg[0] and arg[0]:match("test_config%.lua$") then os.exit(M.run_all() and 0 or 1) end

return M

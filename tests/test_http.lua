#!/usr/bin/env lua
-- ============================================================================
-- Test script for HTTP implementation
-- Run from plugin root: lua test_http.lua
-- ============================================================================

-- Add plugin to path
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

print("Testing leetcode.nvim HTTP implementation")
print("==========================================\n")

-- Test 1: Check curl availability
print("1. Checking curl...")
local handle = io.popen("command -v curl 2>/dev/null")
if handle then
  local result = handle:read("*a")
  handle:close()
  if result and result ~= "" then
    print("   ✓ curl found at: " .. result:gsub("\n", ""))
  else
    print("   ✗ curl not found")
  end
end

-- Test 2: Check luasocket availability
print("\n2. Checking luasocket...")
local ok, socket = pcall(require, "socket.http")
if ok then
  print("   ✓ luasocket available")
else
  print("   ✗ luasocket not available (will use curl)")
end

-- Test 3: Check .env file
print("\n3. Checking .env file...")
local env_path = os.getenv("HOME") .. "/.config/nvim/.env"
local env_file = io.open(env_path, "r")
if env_file then
  print("   ✓ .env file found")
  local has_session = false
  local has_csrf = false
  for line in env_file:lines() do
    if line:match("LC_SESSION=") and not line:match("your_") then has_session = true end
    if line:match("LC_CSRF=") and not line:match("your_") then has_csrf = true end
  end
  env_file:close()

  if has_session and has_csrf then
    print("   ✓ Credentials configured")
  else
    print("   ⚠ .env file needs configuration")
  end
else
  print("   ✗ .env file not found at: " .. env_path)
end

-- Test 4: Check html2text.sh
print("\n4. Checking html2text.sh...")
local script_path = "./scripts/html2text.sh"
local stat = io.popen("ls -la " .. script_path .. " 2>/dev/null")
if stat then
  local result = stat:read("*a")
  stat:close()
  if result and result ~= "" then
    if result:match("^%-rwxr") then
      print("   ✓ html2text.sh found and executable")
    else
      print("   ⚠ html2text.sh found but not executable")
      print("     Run: chmod +x scripts/html2text.sh")
    end
  else
    print("   ✗ html2text.sh not found")
  end
end

print("\n==========================================")
print("Test complete!")
print("\nTo install, run: ./install.sh")
print("Then add to your config: require('leetcode').setup()")

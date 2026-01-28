package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

-- Main test runner for lc_nvim plugin
package.path = "./?.lua;" .. package.path

print("===========================================")
print("    nvimXleetcode Plugin Test Suite")
print("===========================================\n")

-- Run unit tests
print("Running unit tests...")
local unit_tests_ok, unit_tests = pcall(require, "tests.test_unit")
if unit_tests_ok and unit_tests then
  local unit_result = unit_tests.run_all_tests()
  print("\n")
else
  print("✗ Could not load unit tests: " .. tostring(unit_tests))
end

print("\n" .. string.rep("-", 50) .. "\n")

-- Run integration tests
print("Running integration tests...")
local integration_tests_ok, integration_tests = pcall(require, "tests.test_integration")
if integration_tests_ok and integration_tests then
  local integration_result = integration_tests.run_all_tests()
  print("\n")
else
  print("✗ Could not load integration tests: " .. tostring(integration_tests))
end

print("===========================================")
print("           Test Suite Complete")
print("===========================================")

local M = {}
local api = require("leetcode.api")

function M.submit()
  local buf = vim.api.nvim_get_current_buf()
  local slug = vim.b.leetcode_slug
  local question_id = vim.b.leetcode_id

  if not slug then
    vim.notify("Not a LeetCode problem buffer. Open a problem first with :LeetCodeOpen", vim.log.levels.ERROR)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local code = table.concat(lines, "\n")

  if code == "" or code == "\n" then
    vim.notify("Cannot submit empty solution", vim.log.levels.ERROR)
    return
  end

  local leetcode = require("leetcode")
  local lang = leetcode.state.selected_language

  vim.notify("Submitting solution for " .. slug .. " (" .. lang .. ")...", vim.log.levels.INFO)

  api.submit_solution(slug, question_id, code, lang, function(submission_id)
    if submission_id then
      vim.notify("Submission ID: " .. submission_id .. " - Waiting for results...", vim.log.levels.INFO)
      M.poll_submission_result(submission_id)
    else
      vim.notify("Submission failed - check your code and credentials", vim.log.levels.ERROR)
    end
  end)
end

function M.poll_submission_result(submission_id)
  local max_polls = 30
  local poll_count = 0
  local timer_closed = false

  local timer = vim.loop.new_timer()

  local function stop_timer()
    if not timer_closed then
      timer_closed = true
      if timer then
        timer:stop()
        timer:close()
      end
    end
  end

  timer:start(
    1000,
    1000,
    vim.schedule_wrap(function()
      if timer_closed then return end

      poll_count = poll_count + 1

      api.check_submission(submission_id, function(result)
        if timer_closed then return end

        if result and not result.isPending then
          stop_timer()
          M.show_submission_result(result)
        elseif poll_count >= max_polls then
          stop_timer()
          vim.notify("Timeout waiting for result. Check submission at leetcode.com", vim.log.levels.WARN)
        end
      end)
    end)
  )
end

function M.show_submission_result(result)
  local lines = {
    " Submission Result ",
    " " .. string.rep("─", 48),
    "",
  }

  local status = result.statusDisplay or "Unknown"
  local status_code = result.statusCode or 0

  if status_code == 10 then
    table.insert(lines, "  ✓ Accepted!")
    table.insert(lines, "")
    table.insert(lines, "  Runtime: " .. (result.runtimeDisplay or "N/A"))
    if result.runtimePercentile then
      table.insert(lines, "    Beats " .. string.format("%.1f%%", result.runtimePercentile) .. " of submissions")
    end
    table.insert(lines, "")
    table.insert(lines, "  Memory: " .. (result.memoryDisplay or "N/A"))
    if result.memoryPercentile then
      table.insert(lines, "    Beats " .. string.format("%.1f%%", result.memoryPercentile) .. " of submissions")
    end
  elseif status_code == 11 then
    table.insert(lines, "  ✗ Wrong Answer")
    table.insert(lines, "")
    table.insert(
      lines,
      "  Test Cases: " .. (result.totalCorrect or 0) .. "/" .. (result.totalTestcases or 0) .. " passed"
    )
  elseif status_code == 15 then
    table.insert(lines, "  ✗ Runtime Error")
    table.insert(lines, "")
    table.insert(lines, "  " .. status)
  elseif status_code == 20 then
    table.insert(lines, "  ✗ Compile Error")
    table.insert(lines, "")
    table.insert(lines, "  " .. status)
  else
    table.insert(lines, "  Status: " .. status)
    if result.totalCorrect and result.totalTestcases then
      table.insert(lines, "  Test Cases: " .. result.totalCorrect .. "/" .. result.totalTestcases)
    end
  end

  table.insert(lines, "")
  table.insert(lines, "  Press q or <Esc> to close")

  M.show_result_window(lines, status_code == 10)
end

function M.test()
  local buf = vim.api.nvim_get_current_buf()
  local slug = vim.b.leetcode_slug

  if not slug then
    vim.notify("Not a LeetCode problem buffer. Open a problem first with :LeetCodeOpen", vim.log.levels.ERROR)
    return
  end

  local leetcode = require("leetcode")
  local lang = leetcode.state.selected_language

  if lang ~= "python3" then
    vim.notify(
      "Local testing currently only supports Python. Use :LeetCodeSubmit for other languages.",
      vim.log.levels.WARN
    )
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local code = table.concat(lines, "\n")

  if code == "" or code == "\n" then
    vim.notify("Cannot test empty solution", vim.log.levels.ERROR)
    return
  end

  vim.notify("Running local tests for " .. slug .. "...", vim.log.levels.INFO)

  local test_case = vim.b.leetcode_test_case

  if not test_case then
    vim.notify("No test case data available. Problem may need to be re-opened.", vim.log.levels.ERROR)
    return
  end

  M.run_python_test(code, test_case, slug)
end

local function parse_test_case(test_case_str)
  local parts = {}
  for part in test_case_str:gmatch("[^\n]+") do
    table.insert(parts, part)
  end
  return parts
end

function M.run_python_test(code, test_case, slug)
  local temp_file = vim.fn.tempname() .. ".py"

  local class_name = code:match("class%s+(%w+)")
  if not class_name then
    vim.notify("Could not find class definition in code", vim.log.levels.ERROR)
    return
  end

  local func_name = code:match("def%s+(%w+)%(self")
  if not func_name then
    vim.notify("Could not find function definition in code", vim.log.levels.ERROR)
    return
  end

  local test_args = parse_test_case(test_case)

  local test_script = {}
  table.insert(test_script, "import sys")
  table.insert(test_script, "import json")
  table.insert(test_script, "from typing import *")
  table.insert(test_script, "")
  table.insert(test_script, code)
  table.insert(test_script, "")
  table.insert(test_script, "try:")
  table.insert(test_script, "    solution = " .. class_name .. "()")

  for i, arg in ipairs(test_args) do
    table.insert(test_script, string.format("    arg%d = json.loads(%s)", i, vim.fn.json_encode(arg)))
  end

  local arg_list = {}
  for i = 1, #test_args do
    table.insert(arg_list, "arg" .. i)
  end

  table.insert(test_script, "    result = solution." .. func_name .. "(" .. table.concat(arg_list, ", ") .. ")")
  table.insert(test_script, "    print('RESULT:', json.dumps(result))")
  table.insert(test_script, "except Exception as e:")
  table.insert(test_script, "    print('ERROR:', str(e))")
  table.insert(test_script, "    import traceback")
  table.insert(test_script, "    traceback.print_exc()")

  local script_content = table.concat(test_script, "\n")

  local file = io.open(temp_file, "w")
  if not file then
    vim.notify("Failed to create test file", vim.log.levels.ERROR)
    return
  end
  file:write(script_content)
  file:close()

  local cmd = string.format("timeout 5 python3 '%s' 2>&1", temp_file)
  local handle = io.popen(cmd)

  if not handle then
    os.remove(temp_file)
    vim.notify("Failed to execute test", vim.log.levels.ERROR)
    return
  end

  local output = handle:read("*all")
  local success = handle:close()

  os.remove(temp_file)

  M.show_test_result(output, success, test_case)
end

function M.show_test_result(output, success, test_input)
  local lines = {
    " Local Test Result ",
    " " .. string.rep("─", 48),
    "",
  }

  local is_success = false

  if output:match("ERROR:") then
    local error_msg = output:match("ERROR:%s*([^\n]+)")
    if error_msg then
      table.insert(lines, "  ✗ Runtime Error")
      table.insert(lines, "")

      if #error_msg > 46 then
        table.insert(lines, "  " .. error_msg:sub(1, 46))
        table.insert(lines, "  " .. error_msg:sub(47, 92))
      else
        table.insert(lines, "  " .. error_msg)
      end
    else
      table.insert(lines, "  ✗ Runtime Error")
      table.insert(lines, "")
      table.insert(lines, "  Check error details")
    end

    local traceback_started = false
    local tb_count = 0
    for line in output:gmatch("[^\n]+") do
      if line:match("Traceback") then
        traceback_started = true
        table.insert(lines, "")
        table.insert(lines, "  Traceback:")
      elseif traceback_started and tb_count < 3 then
        local clean_line = line:gsub("^%s+", ""):sub(1, 44)
        if clean_line ~= "" and not clean_line:match("^ERROR:") then
          table.insert(lines, "  " .. clean_line)
          tb_count = tb_count + 1
        end
      end
    end
  elseif output:match("RESULT:") then
    local result = output:match("RESULT:%s*([^\n]+)")
    is_success = true
    table.insert(lines, "  ✓ Test Passed")
    table.insert(lines, "")

    local input_display = test_input:gsub("\n", ", ")
    if #input_display > 40 then input_display = input_display:sub(1, 37) .. "..." end
    table.insert(lines, "  Input: " .. input_display)

    if result and #result > 40 then result = result:sub(1, 37) .. "..." end
    table.insert(lines, "  Output: " .. (result or "null"))
  elseif not success then
    table.insert(lines, "  ✗ Timeout")
    table.insert(lines, "")
    table.insert(lines, "  Test exceeded 5 second limit")
  else
    table.insert(lines, "  ✗ Unknown Error")
    table.insert(lines, "")
    local first_line = output:match("[^\n]+") or "No output"
    if #first_line > 46 then first_line = first_line:sub(1, 46) end
    table.insert(lines, "  " .. first_line)
  end

  table.insert(lines, "")
  table.insert(lines, "  Press q or <Esc> to close")

  M.show_result_window(lines, is_success)
end

function M.show_result_window(lines, is_success)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

  local width = 50
  local height = math.min(#lines + 2, 25)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = is_success and " Success! " or " Result ",
    title_pos = "center",
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    callback = function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end,
    noremap = true,
    silent = true,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    callback = function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end,
    noremap = true,
    silent = true,
  })
end

return M

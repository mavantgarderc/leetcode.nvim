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

  local http = require("leetcode.http")
  local original_debug = http.debug
  http.debug = true

  api.submit_solution(slug, question_id, code, lang, function(submission_id)
    http.debug = original_debug

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

  local timer = vim.loop.new_timer()
  timer:start(
    1000,
    1000,
    vim.schedule_wrap(function()
      poll_count = poll_count + 1

      api.check_submission(submission_id, function(result)
        if result and not result.isPending then
          timer:stop()
          timer:close()
          M.show_submission_result(result)
        elseif poll_count >= max_polls then
          timer:stop()
          timer:close()
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

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

  local width = 50
  local height = #lines + 2
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = status_code == 10 and " Success " or " Failed ",
    title_pos = "center",
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    callback = function() vim.api.nvim_win_close(win, true) end,
    noremap = true,
    silent = true,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    callback = function() vim.api.nvim_win_close(win, true) end,
    noremap = true,
    silent = true,
  })
end

function M.test()
  vim.notify("Local testing not yet implemented. Use :LeetCodeSubmit to test on LeetCode.", vim.log.levels.INFO)
end

return M

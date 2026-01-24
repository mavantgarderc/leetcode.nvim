local M = {}
local api = require("leetcode.api")

function M.show_problem_list()
  local leetcode = require("leetcode")

  local now = os.time()
  if leetcode.state.problems_cache and (now - leetcode.state.cache_timestamp) < leetcode.config.cache_ttl then
    local picker = require("leetcode.picker")
    picker.show(leetcode.state.problems_cache)
    return
  end

  vim.notify("Fetching problems...", vim.log.levels.INFO)
  api.get_problems(function(problems)
    if problems and #problems > 0 then
      leetcode.state.problems_cache = problems
      leetcode.state.cache_timestamp = now

      local picker = require("leetcode.picker")
      picker.show(problems)
    else
      vim.notify("No problems fetched. Check your credentials in .env", vim.log.levels.ERROR)
    end
  end)
end

function M.get_status_icon(status)
  local leetcode = require("leetcode")
  if status == "ac" then
    return leetcode.config.icons.solved
  elseif status == "notac" then
    return leetcode.config.icons.attempted
  else
    return leetcode.config.icons.unsolved
  end
end

function M.show_stats(stats)
  if not stats then
    vim.notify("Failed to fetch stats", vim.log.levels.ERROR)
    return
  end

  local lines = {
    " LeetCode Statistics ",
    " " .. string.rep("─", 38),
    "",
  }

  if stats.userStatus and stats.userStatus.username then
    table.insert(lines, "  Username: " .. stats.userStatus.username)
    table.insert(lines, "")
  end

  if stats.matchedUser and stats.matchedUser.submitStats then
    table.insert(lines, "  Problems Solved:")
    for _, stat in ipairs(stats.matchedUser.submitStats.acSubmissionNum) do
      table.insert(lines, "    " .. stat.difficulty .. ": " .. stat.count)
    end
  end

  table.insert(lines, "")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

  local width = 42
  local height = #lines + 2
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = " Stats ",
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

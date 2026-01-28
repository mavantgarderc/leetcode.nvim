local M = {}
local api = require("leetcode.api")
local storage = require("leetcode.storage")

function M.show_problem_list()
  local leetcode = require("leetcode")

  local cached_problems = storage.load_problems()

  if cached_problems then
    vim.notify("Loaded " .. #cached_problems .. " problems from cache", vim.log.levels.INFO)

    cached_problems = storage.enrich_problems(cached_problems)

    local picker = require("leetcode.picker")
    picker.show(cached_problems)

    local cache_info = storage.get_cache_info()
    if cache_info.age and cache_info.age > 3600 then
      vim.notify("Updating problem list in background...", vim.log.levels.INFO)
      M.refresh_problems_background()
    end

    return
  end

  vim.notify("Fetching problems from LeetCode...", vim.log.levels.INFO)
  api.get_problems(function(problems)
    if problems and #problems > 0 then
      storage.save_problems(problems)

      problems = storage.enrich_problems(problems)

      local picker = require("leetcode.picker")
      picker.show(problems)
    else
      vim.notify("No problems fetched. Check your credentials in .env", vim.log.levels.ERROR)
    end
  end)
end

function M.refresh_problems_background()
  api.get_problems(function(problems)
    if problems and #problems > 0 then
      storage.save_problems(problems)
      vim.notify("Problem list updated", vim.log.levels.INFO)
    end
  end)
end

function M.force_refresh()
  storage.clear_cache()
  vim.notify("Clearing cache and fetching fresh data...", vim.log.levels.INFO)
  M.show_problem_list()
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

  local streaks = storage.get_streaks()
  if streaks.current > 0 or streaks.longest > 0 then
    table.insert(lines, "")
    table.insert(lines, "  Streaks:")
    table.insert(lines, "    Current: " .. streaks.current .. " days")
    table.insert(lines, "    Longest: " .. streaks.longest .. " days")
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

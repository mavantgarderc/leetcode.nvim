local M = {}
local storage = require("leetcode.storage")

M.state = {
  problems = {},
  filtered_problems = {},
  selected_index = 1,
  scroll_offset = 0,
  filter = {
    difficulty = nil,
    status = nil,
    search = "",
    bookmarked = false,
  },
  sort_by = "id",
  bufnr = nil,
  winnr = nil,
}

function M.init_from_session()
  local session = storage.load_session()
  if session and session.last_filter then
    M.state.filter = vim.tbl_deep_extend("force", {
      difficulty = nil,
      status = nil,
      search = "",
      bookmarked = false,
    }, session.last_filter)
    M.state.sort_by = session.last_sort or "id"
    M.state.selected_index = session.last_index or 1
  end
end

function M.save_session() storage.save_session(M.state.filter, M.state.sort_by, M.state.selected_index) end

function M.reset()
  M.state.selected_index = 1
  M.state.scroll_offset = 0
  M.state.filter = {
    difficulty = nil,
    status = nil,
    search = "",
    bookmarked = false,
  }
  M.state.sort_by = "id"
end

function M.get_all_topics() return {} end

function M.apply_filters()
  local filtered = {}

  for _, problem in ipairs(M.state.problems) do
    local matches = true

    if problem.isPaidOnly then matches = false end

    if matches and M.state.filter.difficulty then
      if problem.difficulty ~= M.state.filter.difficulty then matches = false end
    end

    if matches and M.state.filter.status then
      if M.state.filter.status == "Solved" and problem.status ~= "ac" then
        matches = false
      elseif M.state.filter.status == "Attempted" and problem.status ~= "notac" then
        matches = false
      elseif M.state.filter.status == "Todo" and (problem.status == "ac" or problem.status == "notac") then
        matches = false
      end
    end

    if matches and M.state.filter.bookmarked then
      if not problem.is_bookmarked then matches = false end
    end

    if matches and M.state.filter.search ~= "" then
      local search_lower = M.state.filter.search:lower()
      local title_lower = problem.title:lower()
      local id_str = tostring(problem.questionFrontendId)

      if not (title_lower:find(search_lower, 1, true) or id_str:find(search_lower, 1, true)) then matches = false end
    end

    if matches then table.insert(filtered, problem) end
  end

  if M.state.sort_by == "id" then
    table.sort(filtered, function(a, b) return tonumber(a.questionFrontendId) < tonumber(b.questionFrontendId) end)
  elseif M.state.sort_by == "title" then
    table.sort(filtered, function(a, b) return a.title < b.title end)
  elseif M.state.sort_by == "difficulty" then
    local difficulty_order = { Easy = 1, Medium = 2, Hard = 3 }
    table.sort(filtered, function(a, b) return difficulty_order[a.difficulty] < difficulty_order[b.difficulty] end)
  elseif M.state.sort_by == "acceptance" then
    table.sort(filtered, function(a, b)
      local rate_a = a.acRate or 0
      local rate_b = b.acRate or 0
      return rate_a > rate_b
    end)
  end

  M.state.filtered_problems = filtered

  if M.state.selected_index > #filtered then M.state.selected_index = math.max(1, #filtered) end
end

local function get_status_icon(status)
  local leetcode = require("leetcode")
  if status == "ac" then
    return leetcode.config.icons.solved
  elseif status == "notac" then
    return leetcode.config.icons.attempted
  else
    return leetcode.config.icons.unsolved
  end
end

function M.get_stats()
  local stats = {
    total = 0,
    solved = 0,
    attempted = 0,
    easy = { total = 0, solved = 0 },
    medium = { total = 0, solved = 0 },
    hard = { total = 0, solved = 0 },
  }

  for _, problem in ipairs(M.state.problems) do
    if not problem.isPaidOnly then
      stats.total = stats.total + 1

      if problem.status == "ac" then
        stats.solved = stats.solved + 1
      elseif problem.status == "notac" then
        stats.attempted = stats.attempted + 1
      end

      local diff = problem.difficulty:lower()
      if stats[diff] then
        stats[diff].total = stats[diff].total + 1
        if problem.status == "ac" then stats[diff].solved = stats[diff].solved + 1 end
      end
    end
  end

  return stats
end

function M.render()
  if not M.state.bufnr or not vim.api.nvim_buf_is_valid(M.state.bufnr) then return end

  local lines = {}
  local highlights = {}
  local leetcode = require("leetcode")
  local config = leetcode.config.picker

  local win_height = vim.api.nvim_win_get_height(M.state.winnr)
  local visible_lines = win_height - 12

  if config.show_stats then
    local stats = M.get_stats()
    local streaks = storage.get_streaks()

    table.insert(
      lines,
      string.format(
        "  LeetCode (%d/%d) | %s | Streak: %d 🔥",
        stats.solved,
        stats.total,
        leetcode.state.selected_language,
        streaks.current
      )
    )
    table.insert(lines, "  " .. string.rep("─", 68))

    local progress = stats.total > 0 and (stats.solved / stats.total * 100) or 0
    local bar_width = 40
    local filled = math.floor(bar_width * progress / 100)
    local bar = string.rep("█", filled) .. string.rep("░", bar_width - filled)
    table.insert(lines, string.format("  [%s] %.1f%%", bar, progress))

    table.insert(
      lines,
      string.format(
        "  Easy: %d/%d  Medium: %d/%d  Hard: %d/%d",
        stats.easy.solved,
        stats.easy.total,
        stats.medium.solved,
        stats.medium.total,
        stats.hard.solved,
        stats.hard.total
      )
    )
    table.insert(lines, "")
  end

  if config.show_filters then
    local filter_parts = {}
    if M.state.filter.difficulty then table.insert(filter_parts, "Diff=" .. M.state.filter.difficulty) end
    if M.state.filter.status then table.insert(filter_parts, "Status=" .. M.state.filter.status) end
    if M.state.filter.bookmarked then table.insert(filter_parts, "Bookmarked") end
    if M.state.filter.search ~= "" then table.insert(filter_parts, "Search='" .. M.state.filter.search .. "'") end

    local filter_str = #filter_parts > 0 and ("  Filters: " .. table.concat(filter_parts, " | ")) or "  No filters"
    table.insert(lines, filter_str .. " | Sort: " .. M.state.sort_by)
    table.insert(lines, "  " .. string.rep("─", 68))
    table.insert(lines, "")
  end

  local header_lines = #lines

  local start_idx = M.state.scroll_offset + 1
  local end_idx = math.min(M.state.scroll_offset + visible_lines, #M.state.filtered_problems)

  for i = start_idx, end_idx do
    local problem = M.state.filtered_problems[i]
    local is_selected = i == M.state.selected_index
    local status_icon = get_status_icon(problem.status)
    local bookmark_icon = problem.is_bookmarked and "★" or " "

    local prefix = is_selected and "▸ " or "  "
    local line = string.format(
      "%s%04d %s%s %-43s %s",
      prefix,
      tonumber(problem.questionFrontendId),
      status_icon,
      bookmark_icon,
      problem.title:sub(1, 43),
      problem.difficulty
    )

    table.insert(lines, line)

    local diff_col = #line - #problem.difficulty
    table.insert(highlights, {
      line = #lines - 1,
      col_start = diff_col,
      col_end = #line,
      hl_group = leetcode.config.difficulty_colors[problem.difficulty] or "Normal",
    })

    if is_selected then
      table.insert(highlights, {
        line = #lines - 1,
        col_start = 0,
        col_end = 2,
        hl_group = "LeetCodeTitle",
      })
    end
  end

  if #M.state.filtered_problems == 0 then table.insert(lines, "  No problems match your filters") end

  table.insert(lines, "")
  table.insert(lines, "  " .. string.rep("─", 68))
  table.insert(lines, "  <CR>=Open | /=Search | f=Filter | b=Bookmark | R=Random | r=Reset | q=Quit")

  vim.api.nvim_buf_set_option(M.state.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.state.bufnr, "modifiable", false)

  vim.api.nvim_buf_clear_namespace(M.state.bufnr, -1, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(M.state.bufnr, -1, hl.hl_group, hl.line, hl.col_start, hl.col_end)
  end

  if M.state.winnr and vim.api.nvim_win_is_valid(M.state.winnr) then
    local cursor_line = header_lines + (M.state.selected_index - M.state.scroll_offset)
    vim.api.nvim_win_set_cursor(M.state.winnr, { cursor_line, 0 })
  end
end

function M.move_cursor(delta)
  if #M.state.filtered_problems == 0 then return end

  M.state.selected_index = M.state.selected_index + delta

  if M.state.selected_index < 1 then
    M.state.selected_index = 1
  elseif M.state.selected_index > #M.state.filtered_problems then
    M.state.selected_index = #M.state.filtered_problems
  end

  if M.state.winnr and vim.api.nvim_win_is_valid(M.state.winnr) then
    local win_height = vim.api.nvim_win_get_height(M.state.winnr)
    local visible_lines = win_height - 12

    if M.state.selected_index > M.state.scroll_offset + visible_lines - 3 then
      M.state.scroll_offset = M.state.selected_index - visible_lines + 3
    end

    if M.state.selected_index < M.state.scroll_offset + 3 then
      M.state.scroll_offset = math.max(0, M.state.selected_index - 3)
    end

    local max_offset = math.max(0, #M.state.filtered_problems - visible_lines)
    M.state.scroll_offset = math.min(M.state.scroll_offset, max_offset)
    M.state.scroll_offset = math.max(0, M.state.scroll_offset)
  end

  M.render()
end

function M.toggle_bookmark()
  if #M.state.filtered_problems == 0 then return end

  local problem = M.state.filtered_problems[M.state.selected_index]

  if problem.is_bookmarked then
    storage.remove_bookmark(problem.titleSlug)
    problem.is_bookmarked = false
    vim.notify("Removed bookmark: " .. problem.title, vim.log.levels.INFO)
  else
    storage.add_bookmark(problem.titleSlug)
    problem.is_bookmarked = true
    vim.notify("Bookmarked: " .. problem.title, vim.log.levels.INFO)
  end

  M.render()
end

function M.open_random()
  if #M.state.filtered_problems == 0 then
    vim.notify("No problems available", vim.log.levels.WARN)
    return
  end

  math.randomseed(os.time())
  local random_index = math.random(1, #M.state.filtered_problems)
  M.state.selected_index = random_index
  M.render()

  vim.defer_fn(function() M.open_selected() end, 100)
end

function M.open_selected()
  if #M.state.filtered_problems == 0 then return end

  local problem = M.state.filtered_problems[M.state.selected_index]

  storage.add_to_history(problem.titleSlug, problem.title)

  M.save_session()

  M.close()
  require("leetcode").open_problem(problem.titleSlug, problem)
end

function M.show_filter_menu()
  local options = {
    "All Difficulties",
    "Easy Only",
    "Medium Only",
    "Hard Only",
    "─────────",
    "All Status",
    "Solved Only",
    "Attempted Only",
    "Todo Only",
    "─────────",
    "Toggle Bookmarked",
  }

  vim.ui.select(options, {
    prompt = "Select Filter",
  }, function(choice)
    if not choice then return end

    if choice == "Easy Only" then
      M.state.filter.difficulty = "Easy"
    elseif choice == "Medium Only" then
      M.state.filter.difficulty = "Medium"
    elseif choice == "Hard Only" then
      M.state.filter.difficulty = "Hard"
    elseif choice == "All Difficulties" then
      M.state.filter.difficulty = nil
    elseif choice == "Solved Only" then
      M.state.filter.status = "Solved"
    elseif choice == "Attempted Only" then
      M.state.filter.status = "Attempted"
    elseif choice == "Todo Only" then
      M.state.filter.status = "Todo"
    elseif choice == "All Status" then
      M.state.filter.status = nil
    elseif choice == "Toggle Bookmarked" then
      M.state.filter.bookmarked = not M.state.filter.bookmarked
    end

    M.apply_filters()
    M.render()
  end)
end

function M.show_sort_menu()
  vim.ui.select({ "By ID", "By Title", "By Difficulty", "By Acceptance Rate" }, {
    prompt = "Sort By",
  }, function(choice)
    if not choice then return end

    if choice == "By ID" then
      M.state.sort_by = "id"
    elseif choice == "By Title" then
      M.state.sort_by = "title"
    elseif choice == "By Difficulty" then
      M.state.sort_by = "difficulty"
    elseif choice == "By Acceptance Rate" then
      M.state.sort_by = "acceptance"
    end

    M.apply_filters()
    M.render()
  end)
end

function M.show_language_menu()
  local leetcode = require("leetcode")
  local options = {}

  for _, lang in ipairs(leetcode.languages) do
    table.insert(options, lang.name)
  end

  vim.ui.select(options, {
    prompt = "Select Language",
  }, function(choice)
    if not choice then return end

    for _, lang in ipairs(leetcode.languages) do
      if lang.name == choice then
        leetcode.state.selected_language = lang.slug
        vim.notify("Language set to: " .. lang.name, vim.log.levels.INFO)
        M.render()
        break
      end
    end
  end)
end

function M.prompt_search()
  vim.ui.input({
    prompt = "Search: ",
    default = M.state.filter.search,
  }, function(input)
    if input ~= nil then
      M.state.filter.search = input
      M.apply_filters()
      M.render()
    end
  end)
end

function M.setup_keymaps()
  local opts = { noremap = true, silent = true, buffer = M.state.bufnr }

  vim.keymap.set("n", "<CR>", M.open_selected, opts)
  vim.keymap.set("n", "q", M.close, opts)
  vim.keymap.set("n", "<Esc>", M.close, opts)
  vim.keymap.set("n", "j", function() M.move_cursor(1) end, opts)
  vim.keymap.set("n", "k", function() M.move_cursor(-1) end, opts)
  vim.keymap.set("n", "<Down>", function() M.move_cursor(1) end, opts)
  vim.keymap.set("n", "<Up>", function() M.move_cursor(-1) end, opts)
  vim.keymap.set("n", "gg", function()
    M.state.selected_index = 1
    M.state.scroll_offset = 0
    M.render()
  end, opts)
  vim.keymap.set("n", "G", function()
    M.state.selected_index = #M.state.filtered_problems
    if M.state.winnr and vim.api.nvim_win_is_valid(M.state.winnr) then
      local win_height = vim.api.nvim_win_get_height(M.state.winnr)
      local visible_lines = win_height - 12
      M.state.scroll_offset = math.max(0, #M.state.filtered_problems - visible_lines)
    end
    M.render()
  end, opts)
  vim.keymap.set("n", "/", M.prompt_search, opts)
  vim.keymap.set("n", "f", M.show_filter_menu, opts)
  vim.keymap.set("n", "s", M.show_sort_menu, opts)
  vim.keymap.set("n", "l", M.show_language_menu, opts)
  vim.keymap.set("n", "b", M.toggle_bookmark, opts)
  vim.keymap.set("n", "R", M.open_random, opts)
  vim.keymap.set("n", "r", function()
    M.reset()
    M.apply_filters()
    M.render()
  end, opts)
end

function M.close()
  M.save_session()

  if M.state.winnr and vim.api.nvim_win_is_valid(M.state.winnr) then vim.api.nvim_win_close(M.state.winnr, true) end

  M.state.bufnr = nil
  M.state.winnr = nil
end

function M.show(problems)
  local leetcode = require("leetcode")
  M.state.problems = problems

  M.init_from_session()

  M.apply_filters()

  M.state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.state.bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(M.state.bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.state.bufnr, "filetype", "leetcode-picker")

  local columns = vim.o.columns
  local lines = vim.o.lines

  local width = math.floor(columns * leetcode.config.picker.width)
  local height = math.floor(lines * leetcode.config.picker.height)

  width = math.min(width, leetcode.config.picker.max_width)
  height = math.min(height, leetcode.config.picker.max_height)

  width = math.max(width, 70)
  height = math.max(height, 20)

  local row = math.floor((lines - height) / 2)
  local col = math.floor((columns - width) / 2)

  M.state.winnr = vim.api.nvim_open_win(M.state.bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = leetcode.config.border_style,
    title = " LeetCode Problem Picker ",
    title_pos = "center",
  })

  vim.api.nvim_win_set_option(M.state.winnr, "number", false)
  vim.api.nvim_win_set_option(M.state.winnr, "relativenumber", false)
  vim.api.nvim_win_set_option(M.state.winnr, "cursorline", true)
  vim.api.nvim_win_set_option(M.state.winnr, "signcolumn", "no")

  M.setup_keymaps()
  M.render()
end

return M

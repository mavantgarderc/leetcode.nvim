local M = {}

local function get_storage_dir()
  local leetcode = require("leetcode")
  local storage_dir = leetcode.config.storage_dir .. "/.leetcode_data"
  vim.fn.mkdir(storage_dir, "p")
  return storage_dir
end

local function read_json(filepath)
  local file = io.open(filepath, "r")
  if not file then return nil end

  local content = file:read("*all")
  file:close()

  if content == "" then return nil end

  local ok, data = pcall(vim.json.decode, content)
  if ok then
    return data
  else
    return nil
  end
end

local function write_json(filepath, data)
  local ok, json_str = pcall(vim.json.encode, data)
  if not ok then return false, "Failed to encode JSON" end

  local file = io.open(filepath, "w")
  if not file then return false, "Failed to open file for writing" end

  file:write(json_str)
  file:close()
  return true
end

function M.save_problems(problems)
  local storage_dir = get_storage_dir()
  local filepath = storage_dir .. "/problems.json"

  local data = {
    timestamp = os.time(),
    version = 1,
    problems = problems,
  }

  return write_json(filepath, data)
end

function M.load_problems()
  local storage_dir = get_storage_dir()
  local filepath = storage_dir .. "/problems.json"

  local data = read_json(filepath)
  if not data then return nil end

  local leetcode = require("leetcode")
  local age = os.time() - data.timestamp

  if age > leetcode.config.cache_ttl then return nil end

  return data.problems
end

function M.load_user_data()
  local storage_dir = get_storage_dir()
  local filepath = storage_dir .. "/user_data.json"

  local data = read_json(filepath)
  if not data then
    return {
      bookmarks = {},
      recently_opened = {},
      presets = {},
      topic_progress = {},
      streaks = {
        current = 0,
        longest = 0,
        last_solve_date = nil,
        history = {},
      },
      session = {
        last_filter = {
          difficulty = nil,
          status = nil,
          search = "",
        },
        last_sort = "id",
        last_index = 1,
      },
    }
  end

  return data
end

function M.save_user_data(data)
  local storage_dir = get_storage_dir()
  local filepath = storage_dir .. "/user_data.json"
  return write_json(filepath, data)
end

function M.add_bookmark(problem_slug)
  local data = M.load_user_data()

  if not data.bookmarks then data.bookmarks = {} end

  data.bookmarks[problem_slug] = {
    added_at = os.time(),
  }

  return M.save_user_data(data)
end

function M.remove_bookmark(problem_slug)
  local data = M.load_user_data()

  if data.bookmarks then data.bookmarks[problem_slug] = nil end

  return M.save_user_data(data)
end

function M.is_bookmarked(problem_slug)
  local data = M.load_user_data()
  return data.bookmarks and data.bookmarks[problem_slug] ~= nil
end

function M.get_bookmarks()
  local data = M.load_user_data()
  return data.bookmarks or {}
end

function M.add_to_history(problem_slug, problem_title)
  local data = M.load_user_data()

  if not data.recently_opened then data.recently_opened = {} end

  for i, item in ipairs(data.recently_opened) do
    if item.slug == problem_slug then
      table.remove(data.recently_opened, i)
      break
    end
  end

  table.insert(data.recently_opened, 1, {
    slug = problem_slug,
    title = problem_title,
    opened_at = os.time(),
  })

  while #data.recently_opened > 50 do
    table.remove(data.recently_opened)
  end

  return M.save_user_data(data)
end

function M.get_recently_opened(limit)
  local data = M.load_user_data()
  local recent = data.recently_opened or {}

  if limit and limit < #recent then
    local limited = {}
    for i = 1, limit do
      table.insert(limited, recent[i])
    end
    return limited
  end

  return recent
end

function M.save_preset(name, filter_config)
  local data = M.load_user_data()

  if not data.presets then data.presets = {} end

  data.presets[name] = {
    filter = filter_config,
    created_at = os.time(),
  }

  return M.save_user_data(data)
end

function M.load_preset(name)
  local data = M.load_user_data()

  if data.presets and data.presets[name] then return data.presets[name].filter end

  return nil
end

function M.get_presets()
  local data = M.load_user_data()
  return data.presets or {}
end

function M.delete_preset(name)
  local data = M.load_user_data()

  if data.presets then data.presets[name] = nil end

  return M.save_user_data(data)
end

function M.save_session(filter, sort_by, selected_index)
  local data = M.load_user_data()

  data.session = {
    last_filter = filter,
    last_sort = sort_by,
    last_index = selected_index,
    saved_at = os.time(),
  }

  return M.save_user_data(data)
end

function M.load_session()
  local data = M.load_user_data()
  return data.session or {}
end

function M.record_solve(problem_slug, difficulty)
  local data = M.load_user_data()

  if not data.streaks then
    data.streaks = {
      current = 0,
      longest = 0,
      last_solve_date = nil,
      history = {},
    }
  end

  local today = os.date("%Y-%m-%d")
  local last_date = data.streaks.last_solve_date

  if last_date == today then
  elseif last_date == os.date("%Y-%m-%d", os.time() - 86400) then
    data.streaks.current = data.streaks.current + 1
  else
    data.streaks.current = 1
  end

  if data.streaks.current > data.streaks.longest then data.streaks.longest = data.streaks.current end

  data.streaks.last_solve_date = today

  if not data.streaks.history[today] then data.streaks.history[today] = {} end

  table.insert(data.streaks.history[today], {
    slug = problem_slug,
    difficulty = difficulty,
    solved_at = os.time(),
  })

  return M.save_user_data(data)
end

function M.get_streaks()
  local data = M.load_user_data()
  return data.streaks or {
    current = 0,
    longest = 0,
    last_solve_date = nil,
    history = {},
  }
end

function M.update_topic_progress(topics, solved)
  local data = M.load_user_data()

  if not data.topic_progress then data.topic_progress = {} end

  for _, topic in ipairs(topics) do
    if not data.topic_progress[topic] then data.topic_progress[topic] = {
      total = 0,
      solved = 0,
    } end

    data.topic_progress[topic].total = data.topic_progress[topic].total + 1

    if solved then data.topic_progress[topic].solved = data.topic_progress[topic].solved + 1 end
  end

  return M.save_user_data(data)
end

function M.get_topic_progress()
  local data = M.load_user_data()
  return data.topic_progress or {}
end

function M.clear_cache()
  local storage_dir = get_storage_dir()
  local filepath = storage_dir .. "/problems.json"

  local ok = os.remove(filepath)
  return ok ~= nil
end

function M.get_cache_info()
  local storage_dir = get_storage_dir()
  local filepath = storage_dir .. "/problems.json"

  local data = read_json(filepath)
  if not data then return {
    exists = false,
    age = nil,
    problem_count = 0,
  } end

  return {
    exists = true,
    age = os.time() - data.timestamp,
    problem_count = data.problems and #data.problems or 0,
    timestamp = data.timestamp,
  }
end

function M.enrich_problems(problems)
  local data = M.load_user_data()
  local bookmarks = data.bookmarks or {}

  for _, problem in ipairs(problems) do
    problem.is_bookmarked = bookmarks[problem.titleSlug] ~= nil
  end

  return problems
end

return M

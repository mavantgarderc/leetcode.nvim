local M = {}

M.state = {
  selected_language = "python3",
  problems_cache = nil,
  cache_timestamp = 0,
  initialized = false,
  deps_ok = false,
  setup_called = false,
}

M.languages = {
  { name = "Python", slug = "python3", ext = "py" },
  { name = "JavaScript", slug = "javascript", ext = "js" },
  { name = "Java", slug = "java", ext = "java" },
  { name = "C++", slug = "cpp", ext = "cpp" },
  { name = "C", slug = "c", ext = "c" },
  { name = "Go", slug = "golang", ext = "go" },
  { name = "Rust", slug = "rust", ext = "rs" },
  { name = "TypeScript", slug = "typescript", ext = "ts" },
  { name = "PHP", slug = "php", ext = "php" },
  { name = "Swift", slug = "swift", ext = "swift" },
  { name = "Kotlin", slug = "kotlin", ext = "kt" },
  { name = "Scala", slug = "scala", ext = "scala" },
  { name = "Ruby", slug = "ruby", ext = "rb" },
}

local function check_dependencies()
  local deps = require("leetcode.deps")
  local ok, err = deps.check_and_install()

  if not ok then
    vim.notify("leetcode.nvim: Dependency check failed\n" .. err, vim.log.levels.ERROR)
    M.state.deps_ok = false
    return false
  end

  M.state.deps_ok = true
  return true
end

local function validate_language(lang_slug)
  for _, lang in ipairs(M.languages) do
    if lang.slug == lang_slug then return true end
  end
  return false
end

function M.setup(opts)
  if M.state.setup_called then
    vim.notify("leetcode.nvim: setup() called multiple times, ignoring", vim.log.levels.WARN)
    return
  end
  M.state.setup_called = true

  local config_manager = require("leetcode.config")
  local ok, result = pcall(config_manager.setup, opts)

  if not ok then
    vim.notify("leetcode.nvim: Configuration error\n" .. tostring(result), vim.log.levels.ERROR)
    return
  end

  M.config = result

  if not validate_language(M.config.default_language) then
    vim.notify(
      string.format(
        "leetcode.nvim: Invalid default_language '%s', falling back to 'python3'",
        M.config.default_language
      ),
      vim.log.levels.WARN
    )
    M.config.default_language = "python3"
  end

  M.state.selected_language = M.config.default_language

  if M.config.debug then
    local http = require("leetcode.http")
    http.debug = true
  end

  if not check_dependencies() then
    vim.notify("leetcode.nvim disabled due to missing dependencies", vim.log.levels.ERROR)
    return
  end

  vim.fn.mkdir(M.config.storage_dir, "p")

  M.setup_highlights()

  M.setup_commands()

  M.state.initialized = true

  local http = require("leetcode.http")
  local method = http.get_method()
  vim.notify(string.format("leetcode.nvim initialized (HTTP: %s)", method), vim.log.levels.INFO)
end

function M.setup_highlights()
  vim.api.nvim_set_hl(0, "LeetCodeEasy", { fg = "#00b8a3", bold = true })
  vim.api.nvim_set_hl(0, "LeetCodeMedium", { fg = "#ffc01e", bold = true })
  vim.api.nvim_set_hl(0, "LeetCodeHard", { fg = "#ff375f", bold = true })
  vim.api.nvim_set_hl(0, "LeetCodeBorder", { fg = "#3e4451" })
  vim.api.nvim_set_hl(0, "LeetCodeTitle", { fg = "#61afef", bold = true })
end

function M.setup_commands()
  vim.api.nvim_create_user_command(
    "LeetCodeList",
    function() M.show_floating_problem_list() end,
    { desc = "Show LeetCode problem list" }
  )

  vim.api.nvim_create_user_command(
    "LeetCodeDaily",
    function() M.open_daily_challenge() end,
    { desc = "Open daily challenge" }
  )

  vim.api.nvim_create_user_command("LeetCodeOpen", function(opts)
    if opts.args and opts.args ~= "" then
      M.open_problem(opts.args)
    else
      M.prompt_for_problem()
    end
  end, { nargs = "?", desc = "Open a problem" })

  vim.api.nvim_create_user_command(
    "LeetCodeSubmit",
    function() M.submit_solution() end,
    { desc = "Submit current solution" }
  )

  vim.api.nvim_create_user_command("LeetCodeTest", function() M.test_solution() end, { desc = "Test current solution" })

  vim.api.nvim_create_user_command("LeetCodeStats", function() M.show_stats() end, { desc = "Show your statistics" })

  vim.api.nvim_create_user_command("LeetCodeInfo", function() M.show_info() end, { desc = "Show plugin information" })

  vim.api.nvim_create_user_command("LeetCodeDebug", function() M.toggle_debug() end, { desc = "Toggle debug mode" })

  vim.api.nvim_create_user_command(
    "LeetCodeConfig",
    function() M.show_config() end,
    { desc = "Show current configuration" }
  )
end

local function ensure_initialized()
  if not M.state.setup_called then
    vim.notify("leetcode.nvim: Please call require('leetcode').setup() in your config", vim.log.levels.ERROR)
    return false
  end

  if not M.state.initialized then
    vim.notify("leetcode.nvim is not properly initialized", vim.log.levels.ERROR)
    return false
  end

  if not M.state.deps_ok then
    vim.notify("leetcode.nvim dependencies not available", vim.log.levels.ERROR)
    return false
  end

  return true
end

function M.show_floating_problem_list()
  if not ensure_initialized() then return end
  require("leetcode.ui").show_problem_list()
end

function M.open_daily_challenge()
  if not ensure_initialized() then return end
  require("leetcode.api").get_daily_challenge(function(problem)
    if problem then M.open_problem(problem.titleSlug, problem) end
  end)
end

function M.open_problem(slug, problem_data)
  if not ensure_initialized() then return end
  require("leetcode.problem").initialize(slug, M.state.selected_language, problem_data)
end

function M.prompt_for_problem()
  if not ensure_initialized() then return end
  vim.ui.input({ prompt = "Problem slug or number: " }, function(input)
    if input then M.open_problem(input) end
  end)
end

function M.submit_solution()
  if not ensure_initialized() then return end
  require("leetcode.submission").submit()
end

function M.test_solution()
  if not ensure_initialized() then return end
  require("leetcode.submission").test()
end

function M.show_stats()
  if not ensure_initialized() then return end
  require("leetcode.api").get_user_stats(function(stats) require("leetcode.ui").show_stats(stats) end)
end

function M.show_info()
  if not ensure_initialized() then return end

  local http = require("leetcode.http")
  local method = http.get_method()

  local info = {
    "LeetCode.nvim Information",
    string.rep("─", 40),
    "",
    "HTTP Method: " .. method,
    "Debug Mode: " .. tostring(http.debug),
    "Storage: " .. M.config.storage_dir,
    "Language: " .. M.state.selected_language,
    "Cache TTL: " .. M.config.cache_ttl .. "s",
    "",
    "Available Commands:",
    "  :LeetCodeList   - Browse problems",
    "  :LeetCodeDaily  - Daily challenge",
    "  :LeetCodeOpen   - Open problem",
    "  :LeetCodeSubmit - Submit solution",
    "  :LeetCodeStats  - View statistics",
    "  :LeetCodeConfig - Show configuration",
    "  :LeetCodeDebug  - Toggle debug mode",
  }

  vim.notify(table.concat(info, "\n"), vim.log.levels.INFO)
end

function M.show_config()
  if not ensure_initialized() then return end

  local lines = {
    "leetcode.nvim Configuration",
    string.rep("=", 50),
    "",
  }

  for key, value in pairs(M.config) do
    local value_str = vim.inspect(value, { newline = " ", indent = "" })
    if #value_str > 50 then value_str = value_str:sub(1, 47) .. "..." end
    table.insert(lines, string.format("%-20s = %s", key, value_str))
  end

  table.insert(lines, "")
  table.insert(lines, "Run :help leetcode-config for documentation")

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

function M.toggle_debug()
  local http = require("leetcode.http")
  http.debug = not http.debug
  M.config.debug = http.debug
  vim.notify("Debug mode: " .. tostring(http.debug), vim.log.levels.INFO)
end

function M.show_recent()
  if not ensure_initialized() then return end

  local storage = require("leetcode.storage")
  local recent = storage.get_recently_opened(20)

  if #recent == 0 then
    vim.notify("No recently opened problems", vim.log.levels.INFO)
    return
  end

  local options = {}
  for _, item in ipairs(recent) do
    table.insert(options, string.format("#%s - %s", item.slug:match("(%d+)") or "?", item.title))
  end

  vim.ui.select(options, {
    prompt = "Recently Opened Problems",
  }, function(choice)
    if not choice then return end

    local idx = nil
    for i, opt in ipairs(options) do
      if opt == choice then
        idx = i
        break
      end
    end

    if idx then M.open_problem(recent[idx].slug) end
  end)
end

function M.show_bookmarks()
  if not ensure_initialized() then return end

  local storage = require("leetcode.storage")
  local bookmarks = storage.get_bookmarks()

  local bookmark_list = {}
  for slug, _ in pairs(bookmarks) do
    table.insert(bookmark_list, slug)
  end

  if #bookmark_list == 0 then
    vim.notify("No bookmarked problems", vim.log.levels.INFO)
    return
  end

  table.sort(bookmark_list)

  vim.ui.select(bookmark_list, {
    prompt = "Bookmarked Problems",
  }, function(choice)
    if choice then M.open_problem(choice) end
  end)
end

function M.open_random()
  if not ensure_initialized() then return end

  local storage = require("leetcode.storage")
  local problems = storage.load_problems()

  if not problems or #problems == 0 then
    vim.notify("No problems available. Run :LeetCodeList first", vim.log.levels.WARN)
    return
  end

  problems = storage.enrich_problems(problems)

  local unsolved = {}
  for _, p in ipairs(problems) do
    if not p.isPaidOnly and p.status ~= "ac" then table.insert(unsolved, p) end
  end

  if #unsolved == 0 then
    vim.notify("Congratulations! You've solved all problems!", vim.log.levels.INFO)
    return
  end

  math.randomseed(os.time())
  local random_problem = unsolved[math.random(1, #unsolved)]

  vim.notify(
    "Random problem: #" .. random_problem.questionFrontendId .. " - " .. random_problem.title,
    vim.log.levels.INFO
  )
  M.open_problem(random_problem.titleSlug, random_problem)
end

return M

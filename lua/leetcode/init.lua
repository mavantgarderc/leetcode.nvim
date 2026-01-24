local M = {}

M.config = {}
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

local defaults = {
  storage_dir = vim.fn.expand("~/leetcode"),
  env_file = vim.fn.expand("~/.config/nvim/.env"),
  cache_ttl = 3600,
  default_language = "python3",
  http_method = nil,
  debug = false,
  border_style = "rounded",
  icons = {
    solved = "✓",
    attempted = "○",
    unsolved = " ",
    locked = "🔒",
  },
  difficulty_colors = {
    Easy = "LeetCodeEasy",
    Medium = "LeetCodeMedium",
    Hard = "LeetCodeHard",
  },
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

function M.setup(opts)
  if M.state.setup_called then return end
  M.state.setup_called = true

  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
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
  vim.api.nvim_create_user_command("LeetCodeList", function() M.show_floating_problem_list() end, {})

  vim.api.nvim_create_user_command("LeetCodeDaily", function() M.open_daily_challenge() end, {})

  vim.api.nvim_create_user_command("LeetCodeOpen", function(opts)
    if opts.args and opts.args ~= "" then
      M.open_problem(opts.args)
    else
      M.prompt_for_problem()
    end
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("LeetCodeSubmit", function() M.submit_solution() end, {})

  vim.api.nvim_create_user_command("LeetCodeTest", function() M.test_solution() end, {})

  vim.api.nvim_create_user_command("LeetCodeStats", function() M.show_stats() end, {})

  vim.api.nvim_create_user_command("LeetCodeInfo", function() M.show_info() end, {})

  vim.api.nvim_create_user_command("LeetCodeDebug", function() M.toggle_debug() end, {})
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
    "  :LeetCodeDebug  - Toggle debug mode",
  }

  vim.notify(table.concat(info, "\n"), vim.log.levels.INFO)
end

function M.toggle_debug()
  local http = require("leetcode.http")
  http.debug = not http.debug
  M.config.debug = http.debug
  vim.notify("Debug mode: " .. tostring(http.debug), vim.log.levels.INFO)
end

return M

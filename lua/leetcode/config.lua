local M = {}

M.schema = {
  storage_dir = {
    type = "string",
    default = vim.fn.expand("~/leetcode"),
    description = "Directory where problems are stored",
    validate = function(value)
      if type(value) ~= "string" then return false, "must be a string" end
      if value == "" then return false, "cannot be empty" end
      return true
    end,
  },

  env_file = {
    type = "string",
    default = vim.fn.expand("~/.config/nvim/.env"),
    description = "Path to .env file containing LC_SESSION and LC_CSRF",
    validate = function(value)
      if type(value) ~= "string" then return false, "must be a string" end
      if value == "" then return false, "cannot be empty" end
      return true
    end,
  },

  cache_ttl = {
    type = "number",
    default = 3600,
    description = "Cache time-to-live in seconds",
    validate = function(value)
      if type(value) ~= "number" then return false, "must be a number" end
      if value < 0 then return false, "must be non-negative" end
      if value > 86400 then return false, "must be <= 86400 (24 hours)" end
      return true
    end,
  },

  default_language = {
    type = "string",
    default = "python3",
    description = "Default programming language",
    validate = function(value)
      if type(value) ~= "string" then return false, "must be a string" end

      return true
    end,
  },

  http_method = {
    type = "string",
    default = nil,
    nullable = true,
    description = "HTTP method: 'socket', 'curl', or nil for auto-detect",
    validate = function(value)
      if value == nil then return true end
      if type(value) ~= "string" then return false, "must be a string or nil" end
      if value ~= "socket" and value ~= "curl" then return false, "must be 'socket', 'curl', or nil" end
      return true
    end,
  },

  debug = {
    type = "boolean",
    default = false,
    description = "Enable debug mode",
    validate = function(value)
      if type(value) ~= "boolean" then return false, "must be a boolean" end
      return true
    end,
  },

  border_style = {
    type = "string",
    default = "rounded",
    description = "Border style for floating windows",
    validate = function(value)
      if type(value) ~= "string" then return false, "must be a string" end
      local valid_styles = { "none", "single", "double", "rounded", "solid", "shadow" }
      for _, style in ipairs(valid_styles) do
        if value == style then return true end
      end
      return false, "must be one of: " .. table.concat(valid_styles, ", ")
    end,
  },

  icons = {
    type = "table",
    default = {
      solved = "✓",
      attempted = "◐",
      unsolved = "○",
      locked = "🔒",
    },
    description = "Icons for problem status",
    validate = function(value)
      if type(value) ~= "table" then return false, "must be a table" end

      local required_keys = { "solved", "attempted", "unsolved", "locked" }
      for _, key in ipairs(required_keys) do
        if not value[key] then return false, "missing required key: " .. key end
        if type(value[key]) ~= "string" then return false, key .. " must be a string" end
      end

      return true
    end,
  },

  difficulty_colors = {
    type = "table",
    default = {
      Easy = "LeetCodeEasy",
      Medium = "LeetCodeMedium",
      Hard = "LeetCodeHard",
    },
    description = "Highlight groups for difficulty levels",
    validate = function(value)
      if type(value) ~= "table" then return false, "must be a table" end

      local required_keys = { "Easy", "Medium", "Hard" }
      for _, key in ipairs(required_keys) do
        if not value[key] then return false, "missing required key: " .. key end
        if type(value[key]) ~= "string" then return false, key .. " must be a string (highlight group name)" end
      end

      return true
    end,
  },

  picker = {
    type = "table",
    default = {
      width = 0.8,
      height = 0.8,
      max_width = 120,
      max_height = 40,
      show_stats = true,
      show_filters = true,
    },
    description = "Problem picker configuration",
    validate = function(value)
      if type(value) ~= "table" then return false, "must be a table" end

      if value.width then
        if type(value.width) ~= "number" then return false, "width must be a number" end
        if value.width <= 0 or value.width > 1 then return false, "width must be between 0 and 1" end
      end

      if value.height then
        if type(value.height) ~= "number" then return false, "height must be a number" end
        if value.height <= 0 or value.height > 1 then return false, "height must be between 0 and 1" end
      end

      if value.max_width then
        if type(value.max_width) ~= "number" then return false, "max_width must be a number" end
        if value.max_width < 40 then return false, "max_width must be >= 40" end
      end

      if value.max_height then
        if type(value.max_height) ~= "number" then return false, "max_height must be a number" end
        if value.max_height < 10 then return false, "max_height must be >= 10" end
      end

      if value.show_stats ~= nil and type(value.show_stats) ~= "boolean" then
        return false, "show_stats must be a boolean"
      end

      if value.show_filters ~= nil and type(value.show_filters) ~= "boolean" then
        return false, "show_filters must be a boolean"
      end

      return true
    end,
  },
}

local function validate_value(key, value, schema_def)
  if value == nil and schema_def.nullable then return true, nil end

  if value == nil then return false, string.format("'%s' is required", key) end

  if schema_def.validate then
    local ok, err = schema_def.validate(value)
    if not ok then return false, string.format("'%s' %s", key, err or "validation failed") end
  end

  return true, nil
end

local function deep_merge(dest, src)
  for key, value in pairs(src) do
    if type(value) == "table" and type(dest[key]) == "table" then
      deep_merge(dest[key], value)
    else
      dest[key] = value
    end
  end
  return dest
end

function M.get_defaults()
  local defaults = {}
  for key, schema_def in pairs(M.schema) do
    defaults[key] = schema_def.default
  end
  return defaults
end

function M.validate(config)
  local errors = {}

  for key, _ in pairs(config) do
    if not M.schema[key] then table.insert(errors, string.format("Unknown config key: '%s'", key)) end
  end

  for key, schema_def in pairs(M.schema) do
    local value = config[key]
    local ok, err = validate_value(key, value, schema_def)
    if not ok then table.insert(errors, err) end
  end

  if #errors > 0 then return false, errors end

  return true, nil
end

function M.merge(user_config)
  local defaults = M.get_defaults()
  local config = vim.deepcopy(defaults)

  if user_config then deep_merge(config, user_config) end

  return config
end

function M.setup(user_config)
  local config = M.merge(user_config or {})

  local ok, errors = M.validate(config)
  if not ok then
    local error_msg = "leetcode.nvim: Invalid configuration\n\n" .. table.concat(errors, "\n")
    error(error_msg)
  end

  return config
end

function M.print_docs()
  local lines = {
    "leetcode.nvim Configuration Options",
    string.rep("=", 50),
    "",
  }

  for key, schema_def in pairs(M.schema) do
    table.insert(lines, string.format("• %s", key))
    table.insert(lines, string.format("  Type: %s%s", schema_def.type, schema_def.nullable and " (nullable)" or ""))
    table.insert(lines, string.format("  Default: %s", vim.inspect(schema_def.default)))
    table.insert(lines, string.format("  Description: %s", schema_def.description))
    table.insert(lines, "")
  end

  print(table.concat(lines, "\n"))
end

function M.export(config, filepath)
  local file = io.open(filepath, "w")
  if not file then return false, "Could not open file for writing" end

  file:write("-- leetcode.nvim configuration\n")
  file:write("-- Generated at: " .. os.date() .. "\n\n")
  file:write("return " .. vim.inspect(config) .. "\n")
  file:close()

  return true
end

return M

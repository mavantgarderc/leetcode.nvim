local M = {}

local function command_exists(cmd)
  local handle = io.popen("command -v " .. cmd .. " 2>/dev/null")
  if not handle then return false end
  local result = handle:read("*a")
  handle:close()
  return result and result ~= ""
end

local function module_exists(name)
  package.loaded[name] = nil -- clear cache
  local ok, _ = pcall(require, name)
  return ok
end

local function get_plugin_root()
  local source = debug.getinfo(1, "S").source:sub(2)
  local plugin_root = vim.fn.fnamemodify(source, ":h:h:h")
  return plugin_root
end

local function check_http()
  local has_socket = module_exists("socket.http")
  local has_curl = command_exists("curl")

  if has_socket then
    vim.notify("✓ LuaSocket available (will use native HTTP)", vim.log.levels.INFO)
    return true, "socket"
  elseif has_curl then
    vim.notify("✓ curl available (will use curl for HTTP)", vim.log.levels.INFO)
    return true, "curl"
  else
    return false,
      "No HTTP method available. Please install either:\n  - luarocks install luasocket\n  - or ensure curl is in your PATH"
  end
end

local function check_html2text()
  local plugin_root = get_plugin_root()
  local script_path = plugin_root .. "/scripts/html2text.sh"

  if vim.fn.filereadable(script_path) == 1 then
    os.execute("chmod +x '" .. script_path .. "' 2>/dev/null")
    return true
  end

  return false, "html2text.sh not found at " .. script_path
end

function M.check_and_install()
  local errors = {}
  local warnings = {}

  local ok, result = check_http()
  if not ok then table.insert(errors, "HTTP: " .. result) end

  ok, err = check_html2text()
  if not ok then table.insert(errors, "html2text.sh: " .. err) end

  if result == "curl" then
    table.insert(warnings, "Tip: Install luasocket for better performance:\n  luarocks install --local luasocket")
  end

  if #warnings > 0 then
    for _, warning in ipairs(warnings) do
      vim.notify(warning, vim.log.levels.WARN)
    end
  end

  if #errors > 0 then
    local error_msg = table.concat(errors, "\n")
    error_msg = error_msg .. "\n\nRequired:\n"
    error_msg = error_msg .. "  - curl (or luarocks install luasocket)\n"
    error_msg = error_msg .. "  - scripts/html2text.sh in plugin directory\n"
    return false, error_msg
  end

  return true
end

function M.get_html2text_path()
  local plugin_root = get_plugin_root()
  return plugin_root .. "/scripts/html2text.sh"
end

return M

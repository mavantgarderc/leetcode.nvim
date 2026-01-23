local M = {}

M.method = nil
M.debug = false

local function debug_log(msg)
  if M.debug then vim.notify("[HTTP Debug] " .. msg, vim.log.levels.DEBUG) end
end

local function parse_env_file(path)
  local env = {}
  local file = io.open(path, "r")

  if not file then return nil, "File not found: " .. path end

  for line in file:lines() do
    if line:match("%S") and not line:match("^%s*#") then
      line = line:gsub("^%s*export%s+", "")

      local key, value = line:match("^%s*([%w_]+)%s*=%s*(.*)%s*$")
      if key and value then
        value = value:gsub("^['\"]", ""):gsub("['\"]$", "")
        env[key] = value
      end
    end
  end

  file:close()
  return env
end

function M.load_auth()
  local config = require("leetcode").config
  local env_file = config.env_file

  local env, err = parse_env_file(env_file)

  if not env then
    error(
      "Failed to load .env file: "
        .. err
        .. "\n\nPlease create "
        .. env_file
        .. " with:\nLC_SESSION=your_session\nLC_CSRF=your_csrf"
    )
  end

  if not env.LC_SESSION or not env.LC_CSRF then
    error(
      "Invalid .env file. Required: LC_SESSION and LC_CSRF\n\nExample:\nLC_SESSION=your_session_token\nLC_CSRF=your_csrf_token"
    )
  end

  debug_log("Auth loaded successfully")
  return {
    session = env.LC_SESSION,
    csrf = env.LC_CSRF,
  }
end

local socket_http = nil
local socket_available = false

local function init_socket()
  if socket_http then return true end

  local ok, http = pcall(require, "socket.http")
  if ok then
    local ltn12_ok, ltn12 = pcall(require, "ltn12")
    if ltn12_ok then
      socket_http = http
      M.ltn12 = ltn12
      socket_available = true
      debug_log("LuaSocket initialized successfully")
      return true
    end
  end

  debug_log("LuaSocket not available")
  return false
end

local function request_socket(method, url, data, headers)
  if not init_socket() then return nil, "Socket not available" end

  debug_log("Using socket for: " .. method .. " " .. url)

  local auth = M.load_auth()

  local request_headers = vim.tbl_extend("force", {
    ["Content-Type"] = "application/json",
    ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
    ["X-CSRFToken"] = auth.csrf,
    ["Referer"] = "https://leetcode.com/",
    ["Cookie"] = "LEETCODE_SESSION=" .. auth.session .. "; csrftoken=" .. auth.csrf,
  }, headers or {})

  local body = data and vim.json.encode(data) or nil

  local response_body = {}
  local res, code, response_headers, status = socket_http.request({
    url = url,
    method = method,
    headers = request_headers,
    source = body and M.ltn12.source.string(body) or nil,
    sink = M.ltn12.sink.table(response_body),
  })

  if not res then
    debug_log("Socket request failed: " .. tostring(code))
    return nil, "HTTP request failed: " .. tostring(code)
  end

  if code ~= 200 then
    debug_log("Socket request returned " .. code)
    return nil, "HTTP " .. code .. ": " .. table.concat(response_body)
  end

  local response_text = table.concat(response_body)
  debug_log("Socket response received: " .. string.len(response_text) .. " bytes")

  local success, result = pcall(vim.json.decode, response_text)
  if success then
    return result, nil
  else
    return response_text, nil
  end
end

local function curl_available()
  local handle = io.popen("command -v curl 2>/dev/null")
  if not handle then return false end
  local result = handle:read("*a")
  handle:close()
  return result and result ~= ""
end

local function shell_escape(str) return "'" .. str:gsub("'", "'\\''") .. "'" end

local function request_curl(method, url, data, headers)
  debug_log("Using curl for: " .. method .. " " .. url)

  local auth = M.load_auth()

  local cmd = "curl -s -X " .. method

  cmd = cmd .. " -H " .. shell_escape("Content-Type: application/json")
  cmd = cmd .. " -H " .. shell_escape("User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36")
  cmd = cmd .. " -H " .. shell_escape("X-CSRFToken: " .. auth.csrf)
  cmd = cmd .. " -H " .. shell_escape("Referer: https://leetcode.com/")
  cmd = cmd .. " -H " .. shell_escape("Cookie: LEETCODE_SESSION=" .. auth.session .. "; csrftoken=" .. auth.csrf)

  if headers then
    for key, value in pairs(headers) do
      cmd = cmd .. " -H " .. shell_escape(key .. ": " .. value)
    end
  end

  if data then
    local json_data = vim.json.encode(data)
    cmd = cmd .. " -d " .. shell_escape(json_data)
  end

  cmd = cmd .. " " .. shell_escape(url)
  cmd = cmd .. " 2>&1"

  debug_log("Executing curl command")

  local handle = io.popen(cmd)
  if not handle then return nil, "Failed to execute curl" end

  local response = handle:read("*a")
  local success = handle:close()

  if not success then
    debug_log("Curl failed")
    return nil, "Curl failed: " .. response
  end

  debug_log("Curl response received: " .. string.len(response) .. " bytes")

  local ok, result = pcall(vim.json.decode, response)
  if ok then
    return result, nil
  else
    return response, nil
  end
end

local function detect_method()
  if M.method then return M.method end

  debug_log("Detecting HTTP method...")

  local config = require("leetcode").config
  if config.http_method then
    debug_log("User preference: " .. config.http_method)
    if config.http_method == "socket" and init_socket() then
      M.method = "socket"
      return "socket"
    elseif config.http_method == "curl" and curl_available() then
      M.method = "curl"
      return "curl"
    end
  end

  if init_socket() then
    M.method = "socket"
    vim.notify("Using Lua socket for HTTP requests", vim.log.levels.INFO)
    return "socket"
  elseif curl_available() then
    M.method = "curl"
    vim.notify("Using curl for HTTP requests", vim.log.levels.INFO)
    return "curl"
  else
    error(
      "No HTTP method available. Please install either:\n  - luarocks install luasocket\n  - or ensure curl is in your PATH"
    )
  end
end

function M.request(method, url, data, headers)
  local http_method = detect_method()

  debug_log("Making " .. method .. " request to " .. url)

  local result, err
  if http_method == "socket" then
    result, err = request_socket(method, url, data, headers)

    if err and curl_available() then
      debug_log("Socket failed, falling back to curl: " .. err)
      vim.notify("Socket request failed, falling back to curl", vim.log.levels.WARN)
      M.method = "curl"
      result, err = request_curl(method, url, data, headers)
    end
  else
    result, err = request_curl(method, url, data, headers)
  end

  if err then
    debug_log("Request failed: " .. err)
    error(err)
  end

  debug_log("Request successful")
  return result
end

function M.graphql(query, variables)
  return M.request("POST", "https://leetcode.com/graphql", {
    query = query,
    variables = variables,
  })
end

function M.get_method()
  detect_method()
  return M.method
end

function M.enable_debug()
  M.debug = true
  vim.notify("HTTP debug mode enabled", vim.log.levels.INFO)
end

return M

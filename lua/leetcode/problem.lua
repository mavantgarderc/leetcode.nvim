local M = {}
local api = require("leetcode.api")
local deps = require("leetcode.deps")

function M.get_extension(lang_slug)
  local leetcode = require("leetcode")
  for _, lang in ipairs(leetcode.languages) do
    if lang.slug == lang_slug then return lang.ext end
  end
  return "txt"
end

function M.html_to_markdown(html_content)
  if not html_content or html_content == "" then
    return "# No description available\n\nThis problem does not have a description."
  end

  local script_path = deps.get_html2text_path()

  if vim.fn.filereadable(script_path) ~= 1 then
    vim.notify("html2text.sh not found, showing raw HTML", vim.log.levels.WARN)
    return html_content
  end

  local temp_html = vim.fn.tempname() .. ".html"
  local temp_md = vim.fn.tempname() .. ".md"

  local file = io.open(temp_html, "w")
  if not file then
    vim.notify("Failed to create temp HTML file", vim.log.levels.WARN)
    return html_content
  end
  file:write(html_content)
  file:close()

  local cmd = string.format("bash '%s' '%s' '%s' 2>&1", script_path, temp_html, temp_md)
  local handle = io.popen(cmd)
  if not handle then
    os.remove(temp_html)
    vim.notify("Failed to execute html2text script", vim.log.levels.WARN)
    return html_content
  end

  local output = handle:read("*all")
  local success = handle:close()

  local content = nil
  if success then
    local md_file = io.open(temp_md, "r")
    if md_file then
      content = md_file:read("*all")
      md_file:close()
    end
  end

  os.remove(temp_html)
  if vim.fn.filereadable(temp_md) == 1 then os.remove(temp_md) end

  if content and content ~= "" then
    return content
  else
    vim.notify("HTML conversion failed: " .. (output or "unknown error"), vim.log.levels.WARN)
    return html_content
  end
end

function M.initialize(slug, lang_slug, problem_data)
  if problem_data then
    M.create_problem_files(slug, lang_slug, problem_data)
  else
    vim.notify("Fetching problem: " .. slug, vim.log.levels.INFO)
    api.get_problem_detail(slug, function(detail)
      if detail then
        M.create_problem_files(slug, lang_slug, detail)
      else
        vim.notify("Failed to fetch problem: " .. slug, vim.log.levels.ERROR)
      end
    end)
  end
end

function M.create_problem_files(slug, lang_slug, detail)
  local leetcode = require("leetcode")
  local problem_dir = leetcode.config.storage_dir .. "/" .. slug

  vim.fn.mkdir(problem_dir, "p")

  local desc_path = problem_dir .. "/description.md"
  local markdown = M.html_to_markdown(detail.content)

  local desc_file = io.open(desc_path, "w")
  if not desc_file then
    vim.notify("Failed to create description file", vim.log.levels.ERROR)
    return
  end
  desc_file:write(markdown)
  desc_file:close()

  local code_snippet = nil
  if detail.codeSnippets then
    for _, snippet in ipairs(detail.codeSnippets) do
      if snippet.langSlug == lang_slug then
        code_snippet = snippet.code
        break
      end
    end
  end

  if not code_snippet then
    vim.notify("No code template found for " .. lang_slug, vim.log.levels.WARN)
    code_snippet = "# No code template available for " .. lang_slug
  end

  local ext = M.get_extension(lang_slug)
  local code_path = problem_dir .. "/" .. slug .. "." .. ext
  local code_file = io.open(code_path, "w")
  if not code_file then
    vim.notify("Failed to create code file", vim.log.levels.ERROR)
    return
  end
  code_file:write(code_snippet)
  code_file:close()

  vim.schedule(function() M.open_split_view(desc_path, code_path, detail) end)
end

function M.open_split_view(desc_path, code_path, detail)
  vim.cmd("only")

  vim.cmd("vsplit")

  vim.cmd("wincmd h")
  vim.cmd("edit " .. vim.fn.fnameescape(desc_path))

  vim.cmd("edit!")

  vim.bo.modifiable = false
  vim.bo.readonly = true
  vim.bo.filetype = "markdown"
  vim.bo.bufhidden = "hide"

  vim.cmd("wincmd l")
  vim.cmd("edit " .. vim.fn.fnameescape(code_path))

  vim.cmd("edit!")

  vim.b.leetcode_slug = detail.titleSlug
  vim.b.leetcode_id = detail.questionId

  vim.notify("Opened: " .. detail.title, vim.log.levels.INFO)
end

return M

local M = {}

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

  local deps = require("leetcode.deps")
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
  vim.notify("Initializing problem: " .. slug .. " (lang: " .. lang_slug .. ")", vim.log.levels.DEBUG)

  if problem_data and problem_data.content then
    vim.notify("Using cached problem data", vim.log.levels.DEBUG)
    M.create_problem_files(slug, lang_slug, problem_data)
  else
    vim.notify("Fetching problem details for: " .. slug, vim.log.levels.INFO)
    local api = require("leetcode.api")
    api.get_problem_detail(slug, function(detail)
      if detail then
        vim.notify("Problem details fetched successfully", vim.log.levels.DEBUG)
        M.create_problem_files(slug, lang_slug, detail)
      else
        vim.notify("Failed to fetch problem: " .. slug, vim.log.levels.ERROR)
      end
    end)
  end
end

function M.create_problem_files(slug, lang_slug, detail)
  vim.notify("Creating problem files for: " .. slug, vim.log.levels.DEBUG)

  local leetcode = require("leetcode")
  local problem_dir = leetcode.config.storage_dir .. "/" .. slug

  vim.fn.mkdir(problem_dir, "p")
  vim.notify("Created directory: " .. problem_dir, vim.log.levels.DEBUG)

  if not detail.content then
    vim.notify("No content field in problem detail!", vim.log.levels.ERROR)
    return
  end

  local desc_path = problem_dir .. "/description.md"
  local markdown = M.html_to_markdown(detail.content)

  local desc_file = io.open(desc_path, "w")
  if not desc_file then
    vim.notify("Failed to create description file: " .. desc_path, vim.log.levels.ERROR)
    return
  end
  desc_file:write(markdown)
  desc_file:close()
  vim.notify("Saved description to: " .. desc_path .. " (" .. #markdown .. " bytes)", vim.log.levels.DEBUG)

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
    vim.notify("Failed to create code file: " .. code_path, vim.log.levels.ERROR)
    return
  end
  code_file:write(code_snippet)
  code_file:close()
  vim.notify("Saved code to: " .. code_path .. " (" .. #code_snippet .. " bytes)", vim.log.levels.DEBUG)

  vim.schedule(function()
    vim.defer_fn(function() M.open_split_view(desc_path, code_path, detail) end, 50)
  end)
end

function M.open_split_view(desc_path, code_path, detail)
  vim.notify("Opening split view", vim.log.levels.DEBUG)

  if vim.fn.filereadable(desc_path) ~= 1 then
    vim.notify("Description file not found: " .. desc_path, vim.log.levels.ERROR)
    return
  end

  if vim.fn.filereadable(code_path) ~= 1 then
    vim.notify("Code file not found: " .. code_path, vim.log.levels.ERROR)
    return
  end

  vim.cmd("only")

  vim.cmd("vsplit")

  vim.cmd("wincmd h")
  vim.cmd("edit " .. vim.fn.fnameescape(desc_path))

  local desc_lines = vim.api.nvim_buf_line_count(0)
  vim.notify("Description buffer loaded: " .. desc_lines .. " lines", vim.log.levels.DEBUG)

  vim.bo.modifiable = false
  vim.bo.readonly = true
  vim.bo.filetype = "markdown"
  vim.bo.bufhidden = "hide"

  vim.cmd("wincmd l")
  vim.cmd("edit " .. vim.fn.fnameescape(code_path))

  local code_lines = vim.api.nvim_buf_line_count(0)
  vim.notify("Code buffer loaded: " .. code_lines .. " lines", vim.log.levels.DEBUG)

  vim.b.leetcode_slug = detail.titleSlug
  vim.b.leetcode_id = detail.questionId

  if detail.sampleTestCase then
    vim.b.leetcode_test_case = detail.sampleTestCase
  elseif detail.exampleTestcases then
    vim.b.leetcode_test_case = detail.exampleTestcases
  end

  vim.notify("Opened: " .. detail.title, vim.log.levels.INFO)
end

return M

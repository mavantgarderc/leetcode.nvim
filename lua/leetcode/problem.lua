local M = {}

function M.get_extension(lang_slug)
  local leetcode = require("leetcode")
  for _, lang in ipairs(leetcode.languages) do
    if lang.slug == lang_slug then return lang.ext end
  end
  return "txt"
end

function M.initialize(slug, lang_slug, problem_data)
  if problem_data and problem_data.content then
    M.create_problem_files(slug, lang_slug, problem_data)
  else
    vim.notify("Fetching problem details for: " .. slug, vim.log.levels.INFO)
    local api = require("leetcode.api")
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

  local formatter = require("leetcode.formatter")
  local markdown = formatter.format_description(detail)

  local desc_path = problem_dir .. "/description.md"
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

  vim.schedule(function()
    vim.defer_fn(function() M.open_split_view(desc_path, code_path, detail) end, 50)
  end)
end

function M.open_split_view(desc_path, code_path, detail)
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

  vim.bo.modifiable = false
  vim.bo.readonly = true
  vim.bo.filetype = "markdown"
  vim.bo.bufhidden = "hide"

  vim.cmd("wincmd l")
  vim.cmd("edit " .. vim.fn.fnameescape(code_path))

  vim.b.leetcode_slug = detail.titleSlug
  vim.b.leetcode_id = detail.questionId

  if detail.sampleTestCase then
    vim.b.leetcode_test_case = detail.sampleTestCase
  elseif detail.exampleTestcases then
    vim.b.leetcode_test_case = detail.exampleTestcases
  end

  vim.diagnostic.disable(0)

  local clients = vim.lsp.get_active_clients({ bufnr = 0 })
  for _, client in ipairs(clients) do
    vim.lsp.diagnostic.disable(0, client.id)
  end

  vim.notify("Opened: " .. detail.title .. " (diagnostics disabled)", vim.log.levels.INFO)
end

return M

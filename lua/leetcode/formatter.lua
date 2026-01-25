local M = {}

local function extract_examples(html)
  local examples = {}

  for example in html:gmatch("<p><strong[^>]*>Example %d+:?</strong></p>.-<pre>(.-)</pre>") do
    table.insert(examples, example)
  end

  return examples
end

local function extract_constraints(html)
  local constraints = {}

  local constraints_section = html:match("<p><strong[^>]*>Constraints:?</strong></p>(.-)</ul>")
  if constraints_section then
    for constraint in constraints_section:gmatch("<li>(.-)</li>") do
      constraint = constraint:gsub("<[^>]+>", "")
      constraint = constraint:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&nbsp;", " ")
      table.insert(constraints, constraint)
    end
  end

  return constraints
end

local function extract_followup(html)
  local followup = html:match("<p><strong[^>]*>Follow[- ]up:?</strong>%s*(.-)</p>")
  if followup then
    followup = followup:gsub("<[^>]+>", "")
    followup = followup:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&nbsp;", " ")
    return followup
  end
  return nil
end

local function format_difficulty(difficulty)
  local indicators = {
    Easy = "🟢 Easy",
    Medium = "🟡 Medium",
    Hard = "🔴 Hard",
  }
  return indicators[difficulty] or difficulty
end

local function format_topics(topics)
  if not topics or #topics == 0 then return "N/A" end

  local badges = {}
  for _, topic in ipairs(topics) do
    table.insert(badges, "`" .. topic.name .. "`")
  end

  return table.concat(badges, " ")
end

function M.format_description(detail)
  local lines = {}

  table.insert(lines, "# " .. detail.questionFrontendId .. ". " .. detail.title)
  table.insert(lines, "")

  table.insert(lines, "---")
  table.insert(lines, "")
  table.insert(lines, "**Difficulty:** " .. format_difficulty(detail.difficulty))
  table.insert(lines, "")

  if detail.topicTags and #detail.topicTags > 0 then
    table.insert(lines, "**Topics:** " .. format_topics(detail.topicTags))
    table.insert(lines, "")
  end

  if detail.companyTags and #detail.companyTags > 0 then
    local companies = {}
    for _, company in ipairs(detail.companyTags) do
      table.insert(companies, company.name)
    end
    table.insert(lines, "**Companies:** " .. table.concat(companies, ", "))
    table.insert(lines, "")
  end

  table.insert(lines, "---")
  table.insert(lines, "")

  table.insert(lines, "## Description")
  table.insert(lines, "")

  local description = detail.content or ""

  description = description:gsub("<p><strong[^>]*>Example.-</strong></p>.-<pre>.-</pre>", "")
  description = description:gsub("<p><strong[^>]*>Constraints:?</strong></p>.-</ul>", "")
  description = description:gsub("<p><strong[^>]*>Follow[- ]up:?</strong>.-</p>", "")
  description = description:gsub("<strong>", "**"):gsub("</strong>", "**")
  description = description:gsub("<em>", "*"):gsub("</em>", "*")
  description = description:gsub("<code>", "`"):gsub("</code>", "`")
  description = description:gsub("<sup>", "^"):gsub("</sup>", "")
  description = description:gsub("<sub>", "_"):gsub("</sub>", "")
  description = description:gsub("<p>", ""):gsub("</p>", "\n\n")
  description = description:gsub("<li>", "- "):gsub("</li>", "\n")
  description = description:gsub("<ul>", "\n"):gsub("</ul>", "\n")
  description = description:gsub("<ol>", "\n"):gsub("</ol>", "\n")
  description = description:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&nbsp;", " ")
  description = description:gsub("&quot;", '"'):gsub("&#39;", "'")
  description = description:gsub("<[^>]+>", "")
  description = description:gsub("\n\n\n+", "\n\n")

  for line in description:gmatch("[^\n]+") do
    table.insert(lines, line)
  end

  table.insert(lines, "")

  local examples = extract_examples(detail.content or "")
  if #examples > 0 then
    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "## Examples")
    table.insert(lines, "")

    for i, example in ipairs(examples) do
      table.insert(lines, "### Example " .. i)
      table.insert(lines, "")
      table.insert(lines, "```")

      example = example:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&nbsp;", " ")
      example = example:gsub("<[^>]+>", "")

      for line in example:gmatch("[^\n]+") do
        if line:match("%S") then table.insert(lines, line) end
      end

      table.insert(lines, "```")
      table.insert(lines, "")
    end
  end

  local constraints = extract_constraints(detail.content or "")
  if #constraints > 0 then
    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "## Constraints")
    table.insert(lines, "")

    for _, constraint in ipairs(constraints) do
      table.insert(lines, "- " .. constraint)
    end

    table.insert(lines, "")
  end

  local followup = extract_followup(detail.content or "")
  if followup then
    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "## Follow-up")
    table.insert(lines, "")
    table.insert(lines, followup)
    table.insert(lines, "")
  end

  if detail.hints and #detail.hints > 0 then
    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "## Hints")
    table.insert(lines, "")

    for i, hint in ipairs(detail.hints) do
      table.insert(lines, "**Hint " .. i .. ":** " .. hint)
      table.insert(lines, "")
    end
  end

  if detail.similarQuestions and detail.similarQuestions ~= "" then
    local ok, similar = pcall(vim.json.decode, detail.similarQuestions)
    if ok and similar and #similar > 0 then
      table.insert(lines, "---")
      table.insert(lines, "")
      table.insert(lines, "## Similar Questions")
      table.insert(lines, "")

      for _, q in ipairs(similar) do
        table.insert(
          lines,
          "- [" .. q.title .. "](https://leetcode.com/problems/" .. q.titleSlug .. ") (" .. q.difficulty .. ")"
        )
      end

      table.insert(lines, "")
    end
  end

  return table.concat(lines, "\n")
end

return M

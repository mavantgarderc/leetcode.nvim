local M = {}

function M.get_problems(callback)
  local query = [[
    query problemsetQuestionList {
      problemsetQuestionList: questionList(
        categorySlug: ""
        limit: -1
        skip: 0
        filters: {}
      ) {
        questions: data {
          questionFrontendId
          title
          titleSlug
          difficulty
          status
          isPaidOnly
        }
      }
    }
  ]]

  vim.schedule(function()
    local http = require("leetcode.http")
    local success, result = pcall(http.graphql, query)

    if not success then
      vim.notify("Failed to fetch problems: " .. tostring(result), vim.log.levels.ERROR)
      callback(nil)
      return
    end

    if
      result
      and result.data
      and result.data.problemsetQuestionList
      and result.data.problemsetQuestionList.questions
    then
      local count = #result.data.problemsetQuestionList.questions
      vim.notify("Found " .. count .. " problems", vim.log.levels.INFO)
      callback(result.data.problemsetQuestionList.questions)
    else
      vim.notify("Invalid response from LeetCode API", vim.log.levels.ERROR)
      callback(nil)
    end
  end)
end

function M.get_problem_detail(slug, callback)
  local query = [[
    query getQuestionDetail($titleSlug: String!) {
      question(titleSlug: $titleSlug) {
        questionId
        questionFrontendId
        title
        titleSlug
        content
        difficulty
        likes
        dislikes
        similarQuestions
        topicTags {
          name
          slug
        }
        companyTagStats
        codeSnippets {
          lang
          langSlug
          code
        }
        sampleTestCase
        exampleTestcases
        hints
        solution {
          id
          canSeeDetail
        }
      }
    }
  ]]

  vim.schedule(function()
    local http = require("leetcode.http")
    local success, result = pcall(http.graphql, query, { titleSlug = slug })

    if not success then
      vim.notify("Failed to fetch problem: " .. tostring(result), vim.log.levels.ERROR)
      callback(nil)
      return
    end

    if result and result.data and result.data.question then
      callback(result.data.question)
    else
      if result and result.errors then
        local error_msg = result.errors[1].message or "Unknown error"
        vim.notify("LeetCode API error: " .. error_msg, vim.log.levels.ERROR)
      else
        vim.notify("Problem not found: " .. slug, vim.log.levels.ERROR)
      end
      callback(nil)
    end
  end)
end

function M.get_daily_challenge(callback)
  local query = [[
    query questionOfToday {
      activeDailyCodingChallengeQuestion {
        date
        link
        question {
          questionId
          questionFrontendId
          title
          titleSlug
          difficulty
        }
      }
    }
  ]]

  vim.schedule(function()
    local http = require("leetcode.http")
    local success, result = pcall(http.graphql, query)

    if not success then
      vim.notify("Failed to fetch daily challenge: " .. tostring(result), vim.log.levels.ERROR)
      callback(nil)
      return
    end

    if result and result.data and result.data.activeDailyCodingChallengeQuestion then
      local daily = result.data.activeDailyCodingChallengeQuestion
      callback(daily.question)
    else
      vim.notify("No daily challenge available", vim.log.levels.WARN)
      callback(nil)
    end
  end)
end

function M.submit_solution(slug, question_id, code, lang, callback)
  local url = "https://leetcode.com/problems/" .. slug .. "/submit/"

  vim.schedule(function()
    local http = require("leetcode.http")

    local data = {
      lang = lang,
      question_id = question_id,
      typed_code = code,
    }

    local success, result = pcall(http.request, "POST", url, data)

    if not success then
      vim.notify("Submission request failed: " .. tostring(result), vim.log.levels.ERROR)
      callback(nil)
      return
    end

    if type(result) == "table" then
      if result.submission_id then
        callback(tonumber(result.submission_id))
      elseif result.interpret_id then
        callback(tonumber(result.interpret_id))
      elseif result.error then
        vim.notify("Submission error: " .. result.error, vim.log.levels.ERROR)
        callback(nil)
      else
        vim.notify("Unexpected response structure", vim.log.levels.ERROR)
        callback(nil)
      end
    else
      vim.notify("Invalid response type from submission", vim.log.levels.ERROR)
      callback(nil)
    end
  end)
end

function M.check_submission(submission_id, callback)
  local url = "https://leetcode.com/submissions/detail/" .. submission_id .. "/check/"

  vim.schedule(function()
    local http = require("leetcode.http")
    local success, result = pcall(http.request, "GET", url)

    if not success then
      callback(nil)
      return
    end

    if result and type(result) == "table" then
      local memory_num = nil
      if result.status_memory and type(result.status_memory) == "string" then
        memory_num = tonumber(result.status_memory:match("([%d.]+)"))
      elseif result.status_memory and type(result.status_memory) == "number" then
        memory_num = result.status_memory
      end

      local runtime_num = nil
      if result.status_runtime and type(result.status_runtime) == "string" then
        runtime_num = tonumber(result.status_runtime:match("([%d.]+)"))
      elseif result.status_runtime and type(result.status_runtime) == "number" then
        runtime_num = result.status_runtime
      end

      local formatted = {
        statusCode = result.status_code,
        statusDisplay = result.status_msg,
        isPending = result.state ~= "SUCCESS",
        runtime = runtime_num,
        runtimeDisplay = result.status_runtime,
        runtimePercentile = result.runtime_percentile,
        memory = memory_num,
        memoryDisplay = result.status_memory,
        memoryPercentile = result.memory_percentile,
        totalCorrect = result.total_correct,
        totalTestcases = result.total_testcases,
      }
      callback(formatted)
    else
      callback(nil)
    end
  end)
end

function M.get_user_stats(callback)
  local query = [[
    query {
      userStatus {
        username
        activeSessionId
      }
      matchedUser(username: "") {
        submitStats: submitStatsGlobal {
          acSubmissionNum {
            difficulty
            count
          }
        }
      }
    }
  ]]

  vim.schedule(function()
    local http = require("leetcode.http")
    local success, result = pcall(http.graphql, query)

    if success and result and result.data then
      callback(result.data)
    else
      vim.notify("Failed to fetch stats", vim.log.levels.ERROR)
      callback(nil)
    end
  end)
end

return M

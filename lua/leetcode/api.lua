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

    if result and result.data and result.data.problemsetQuestionList then
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
        codeSnippets {
          lang
          langSlug
          code
        }
        sampleTestCase
        exampleTestcases
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

function M.submit_solution(slug, code, lang, callback)
  local url = "https://leetcode.com/problems/" .. slug .. "/submit/"

  vim.schedule(function()
    local http = require("leetcode.http")
    local success, result = pcall(http.request, "POST", url, {
      lang = lang,
      question_id = tostring(slug),
      typed_code = code,
    })

    if not success then
      vim.notify("Failed to submit solution: " .. tostring(result), vim.log.levels.ERROR)
      callback(nil)
      return
    end

    if result and result.submission_id then
      callback(result.submission_id)
    else
      vim.notify("Submission failed - invalid response", vim.log.levels.ERROR)
      callback(nil)
    end
  end)
end

function M.check_submission(submission_id, callback)
  local query = [[
    query submissionDetails($submissionId: Int!) {
      submissionDetails(submissionId: $submissionId) {
        runtime
        runtimeDisplay
        runtimePercentile
        memory
        memoryDisplay
        memoryPercentile
        statusCode
        statusDisplay
        lang
        totalCorrect
        totalTestcases
        isPending
      }
    }
  ]]

  vim.schedule(function()
    local http = require("leetcode.http")
    local success, result = pcall(http.graphql, query, { submissionId = submission_id })

    if success and result and result.data then
      callback(result.data.submissionDetails)
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

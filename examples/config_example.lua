require("leetcode").setup()

-- Example 1: Basic customization
require("leetcode").setup({
  -- Where to store problem files
  storage_dir = vim.fn.expand("~/coding/leetcode"),

  -- Path to .env file with credentials
  env_file = vim.fn.expand("~/.leetcode.env"),

  -- Default language for new problems
  default_language = "python3",

  -- Cache duration (1 hour)
  cache_ttl = 3600,
})

-- Example 2: Advanced configuration
require("leetcode").setup({
  storage_dir = vim.fn.expand("~/leetcode"),
  env_file = vim.fn.expand("~/.config/nvim/.env"),
  cache_ttl = 7200, -- 2 hours

  -- Preferred HTTP method: "socket", "curl", or nil (auto-detect)
  http_method = nil,

  -- Enable debug logging
  debug = false,

  -- Floating window border style
  border_style = "rounded", -- "none", "single", "double", "rounded", "solid", "shadow"

  -- Custom status icons
  icons = {
    solved = "✓",
    attempted = "◐",
    unsolved = "○",
    locked = "🔒",
  },

  -- Custom difficulty colors (highlight groups)
  difficulty_colors = {
    Easy = "LeetCodeEasy",
    Medium = "LeetCodeMedium",
    Hard = "LeetCodeHard",
  },

  -- Problem picker settings
  picker = {
    width = 0.8, -- 80% of editor width
    height = 0.8, -- 80% of editor height
    max_width = 120, -- Maximum width in columns
    max_height = 40, -- Maximum height in lines
    show_stats = true, -- Show statistics
    show_filters = true, -- Show filter info
  },
})

-- Example 3: Language-specific setup
require("leetcode").setup({
  default_language = "rust", -- For Rust developers
  storage_dir = vim.fn.expand("~/projects/leetcode-rust"),
})

-- Example 4: Competitive programming setup
require("leetcode").setup({
  default_language = "cpp",
  cache_ttl = 300, -- Short cache (5 minutes) for frequent updates
  debug = true, -- Enable debugging
  border_style = "double",
})

-- Example 5: Minimal UI setup
require("leetcode").setup({
  border_style = "none",
  icons = {
    solved = "[x]",
    attempted = "[ ]",
    unsolved = "[ ]",
    locked = "[!]",
  },
})

-- ============================================================================
-- Keybindings (optional)
-- ============================================================================

-- Global keybindings
vim.keymap.set("n", "<leader>lcq", ":LeetCodeList<CR>", { desc = "LeetCode: List problems" })
vim.keymap.set("n", "<leader>lcd", ":LeetCodeDaily<CR>", { desc = "LeetCode: Daily challenge" })
vim.keymap.set("n", "<leader>lci", ":LeetCodeInfo<CR>", { desc = "LeetCode: Info" })
vim.keymap.set("n", "<leader>lcc", ":LeetCodeConfig<CR>", { desc = "LeetCode: Config" })

-- Solution buffer keybindings (set automatically in leetcode problem files)
-- <leader>ls - Submit solution
-- <leader>lt - Test solution locally
-- <leader>ll - Open problem list

-- ============================================================================
-- Commands
-- ============================================================================

-- :LeetCodeList          - Browse all problems
-- :LeetCodeDaily         - Open today's challenge
-- :LeetCodeOpen <slug>   - Open specific problem
-- :LeetCodeSubmit        - Submit current solution
-- :LeetCodeTest          - Test solution locally (Python only)
-- :LeetCodeStats         - View your statistics
-- :LeetCodeInfo          - Show plugin information
-- :LeetCodeConfig        - Show current configuration
-- :LeetCodeDebug         - Toggle debug mode

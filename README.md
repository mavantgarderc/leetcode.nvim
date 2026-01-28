# leetcode.nvim

do leetcodes in nvim... lazy & exhausted as that...

## Features

- Fetch & display problems with status & difficulty by the picker.
- Automated splitted window, minimal, but similar to leetcode website.
- Responsive UI & window splitting strategy based on terminal width & height.
- Do leetcodes in any language you want by the panel, or set a default one by your personal configuration.

## Prerequisites

- Neovim >= 0.5
- Lua 5.1+ with LuaSocket and Lua-cjson modules
- The Lua scripts in the `lua_scripts/` directory

## Setup

### Authentication

Create a `.env` file at `~/.config/nvim/.env` with your LeetCode session information:

```
LC_SESSION=your_leetcode_session_token
LC_CSRF=your_csrf_token
```

To get these tokens:

1. Login to LeetCode in your browser
2. Open developer tools (F12)
3. Go to the Application/Storage tab
4. Find `LEETCODE_SESSION` and `csrftoken` cookies
5. Copy the values to your `.env` file

### Installation

#### Using Lazy.nvim

Add this to your `lazy.nvim` plugins:

```lua
{
  "mavantgarderc/leetcode.nvim",
  config = function()
    require("leetcode").setup()
  end
}
```

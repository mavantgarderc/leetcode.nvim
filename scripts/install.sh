#!/usr/bin/env bash
set -e

echo "Installing leetcode.nvim..."

check_curl() {
	if command -v curl &>/dev/null; then
		echo "(✓) curl found"
		return 0
	else
		echo " * * * curl not found * * * "
		echo ""
		echo "Please install curl:"
		echo "  Ubuntu/Debian: sudo apt-get install curl"
		echo "  macOS: brew install curl"
		echo "  Arch: sudo pacman -S curl"
		return 1
	fi
}

check_luasocket() {
	if command -v luarocks &>/dev/null; then
		echo "(✓) luarocks found"

		if luarocks install --local luasocket 2>/dev/null; then
			echo "(✓) luasocket installed (better performance)"
		else
			echo "(x)  Could not install luasocket (will use curl fallback)"
		fi
	else
		echo "(x)  luarocks not found (optional - will use curl)"
		echo "   Tip: Install luarocks for better performance"
	fi
}

make_executable() {
	local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local html2text_script="$script_dir/html2text.sh"

	if [ -f "$html2text_script" ]; then
		chmod +x "$html2text_script"
		echo "((✓)) Made html2text.sh executable"
	else
		echo "(x) html2text.sh not found at $html2text_script"
		return 1
	fi
}

create_env_template() {
	local env_file="$HOME/.config/nvim/.env"

	if [ -f "$env_file" ]; then
		echo "(✓) .env file already exists"
		return 0
	fi

	echo "(i) Creating .env template..."
	mkdir -p "$(dirname "$env_file")"

	cat >"$env_file" <<'EOF'
# LeetCode Session Credentials
# Get these from your browser after logging into LeetCode:
# 1. Open Developer Tools (F12)
# 2. Go to Application/Storage -> Cookies -> https://leetcode.com
# 3. Copy the values below

LC_SESSION=your_leetcode_session_token_here
LC_CSRF=your_csrf_token_here
EOF

	echo "(✓) Created .env template at $env_file"
}

main() {
	local has_errors=0

	if ! check_curl; then
		has_errors=1
	fi

	check_luasocket

	if ! make_executable; then
		has_errors=1
	fi

	create_env_template

	echo ""

	if [ $has_errors -eq 0 ]; then
		echo "(✓) Installation complete!"
		echo ""
		echo "Next steps:"
		echo "1. Edit ~/.config/nvim/.env with your LeetCode credentials"
		echo "2. Add to your Neovim config:"
		echo "   require('leetcode').setup()"
		echo "3. Restart Neovim"
		echo ""
		echo "Optional: Install luasocket for better performance:"
		echo "   luarocks install --local luasocket"
	else
		echo "(x) Installation failed"
		echo ""
		echo "Please fix the errors above and try again"
		exit 1
	fi
}

main

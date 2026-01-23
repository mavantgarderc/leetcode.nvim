#!/usr/bin/env bash

# ./verify_problem.sh two-sum

PROBLEM_SLUG="${1:-two-sum}"
STORAGE_DIR="${2:-$HOME/leetcode}"
PROBLEM_DIR="$STORAGE_DIR/$PROBLEM_SLUG"

echo "Verifying problem: $PROBLEM_SLUG"
echo "Location: $PROBLEM_DIR"
echo ""

if [ ! -d "$PROBLEM_DIR" ]; then
	echo "(x) Problem directory does not exist"
	exit 1
fi

echo "(✓) Problem directory exists"
echo ""

if [ -f "$PROBLEM_DIR/description.md" ]; then
	SIZE=$(wc -c <"$PROBLEM_DIR/description.md")
	LINES=$(wc -l <"$PROBLEM_DIR/description.md")
	echo "(✓) description.md exists"
	echo "  Size: $SIZE bytes"
	echo "  Lines: $LINES"
	echo ""
	echo "First 10 lines:"
	head -10 "$PROBLEM_DIR/description.md"
	echo ""
else
	echo "(x) description.md does not exist"
fi

CODE_FILE=$(find "$PROBLEM_DIR" -type f -name "$PROBLEM_SLUG.*" ! -name "*.md" | head -1)
if [ -n "$CODE_FILE" ]; then
	SIZE=$(wc -c <"$CODE_FILE")
	LINES=$(wc -l <"$CODE_FILE")
	echo "✓ Code file exists: $(basename "$CODE_FILE")"
	echo "  Size: $SIZE bytes"
	echo "  Lines: $LINES"
	echo ""
	echo "Content:"
	cat "$CODE_FILE"
else
	echo "(x) No code file found"
fi

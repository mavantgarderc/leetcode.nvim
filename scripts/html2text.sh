#!/usr/bin/env bash

# ./html2text.sh input.html output.txt

set -euo pipefail

if [ $# -ne 2 ]; then
	echo "Usage: $0 <input.html> <output.txt>" >&2
	exit 1
fi

INPUT="$1"
OUTPUT="$2"

if [ ! -f "$INPUT" ]; then
	echo "Error: Input file not found: $INPUT" >&2
	exit 1
fi

if [ ! -s "$INPUT" ]; then
	echo "Error: Input file is empty: $INPUT" >&2
	exit 1
fi

# HTML => text (sed) => preserves structure while removing HTML tags
sed -e 's/<[^>]*>//g' \
	-e 's/&nbsp;/ /g' \
	-e 's/&lt;/</g' \
	-e 's/&gt;/>/g' \
	-e 's/&amp;/\&/g' \
	-e 's/&quot;/"/g' \
	-e 's/&#39;/'"'"'/g' \
	-e 's/&ndash;/–/g' \
	-e 's/&mdash;/—/g' \
	-e 's/^[[:space:]]*$//' \
	"$INPUT" | grep -v '^$' >"$OUTPUT"

# verify output was created and is not empty
if [ ! -s "$OUTPUT" ]; then
	echo "Error: Failed to create output or output is empty" >&2
	exit 1
fi

exit 0

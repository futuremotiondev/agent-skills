#!/usr/bin/env bash
# =============================================================================
# validate-markdown.sh — Lint a markdown file for common formatting issues.
#
# USAGE
#   ./validate-markdown.sh [--] <file.md>
#
#   The optional "--" separator lets you pass filenames that start with a
#   dash (e.g. "--weird-name.md") without the shell treating them as flags.
#
# EXIT CODES
#   0 — no errors (warnings are allowed)
#   1 — argument/file errors or one or more hard validation errors
#
# CHECKS PERFORMED
#    1.  File ends with a newline              (POSIX requirement)
#    2.  No trailing whitespace on any line
#    3.  No hard tabs                          (use spaces)
#    4.  Fenced code blocks have language identifiers
#    5.  No three or more consecutive blank lines
#    6.  No Setext (underline-style) headers   (use ATX #)
#    7.  Consistent list markers              (prefer -)
#    8.  Descriptive link text               (no "click here" / "here")
#    9.  Images have alt text
#   10.  Emphasis uses ** / * not __ / _
#   11.  Unescaped <placeholder> patterns outside code blocks  (MD033)
#   12.  Table pipe spacing — cells have surrounding spaces    (MD060)
#   13.  Table column alignment — rows have equal widths       (MD060)
#
# REQUIREMENTS
#   bash 4+, GNU grep (for -P / PCRE support), GNU awk
#   On Windows: run via Git Bash, WSL, or a comparable POSIX layer.
# =============================================================================

# -e             abort immediately if any command exits non-zero
# -u             treat unset variables as errors
# -o pipefail    propagate failures through pipelines (not just the last stage)
set -euo pipefail

# =============================================================================
# ANSI color helpers
# Colors are suppressed when stdout is not an interactive terminal — this keeps
# CI logs and file redirections clean.
# =============================================================================
if [ -t 1 ]; then
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[0;32m'
    NC='\033[0m'   # reset — "No Color"
else
    RED='' YELLOW='' GREEN='' NC=''
fi

# =============================================================================
# Counters and helper functions
#
# The "(( VAR++ )) || true" pattern is necessary under set -e: arithmetic
# commands exit with status 1 when the result is zero, which Bash treats as
# failure.  "|| true" prevents that from aborting the script on the very first
# increment (when WARNINGS or ERRORS starts at 0).
# =============================================================================
ERRORS=0
WARNINGS=0

warn() {
    echo -e "${YELLOW}WARNING: $*${NC}"
    (( WARNINGS++ )) || true
}

error() {
    echo -e "${RED}ERROR: $*${NC}"
    (( ERRORS++ )) || true
}

# =============================================================================
# Argument parsing
#
# We iterate instead of using getopts because we only have one real argument
# (the filename) and one pseudo-flag ("--").  Anything that isn't "--" is
# treated as the filename.  If two filenames are passed, the last one wins —
# acceptable simplification for a single-file tool.
# =============================================================================
FILE=""
for arg in "$@"; do
    case "$arg" in
        --) ;;          # end-of-options sentinel — skip it, not a filename
        *)  FILE="$arg" ;;
    esac
done

if [ -z "$FILE" ]; then
    echo -e "${RED}Error: No file specified${NC}"
    echo "Usage: $0 [--] <markdown-file>"
    exit 1
fi

# =============================================================================
# Input validation
#
# All checks run before we open the file so that untrusted input cannot cause
# unintended filesystem side effects.
# =============================================================================

# Reject directory traversal sequences.  ".." in a path could escape the
# intended working directory and reach system files.
if [[ "$FILE" == *".."* ]]; then
    echo -e "${RED}Error: Path traversal sequences (..) are not allowed${NC}"
    exit 1
fi

# Whitelist safe path characters: letters, digits, dot, underscore, colon
# (Windows drive letter separator), forward slash, space, and hyphen.
# Backslash is intentionally excluded — pass Unix-style paths to this script.
#
# Bug note: the original regex used [' '-] which creates a character-class
# range from space (ASCII 32) to whatever followed, rather than allowing
# space and dash individually.  This is the corrected form.
if [[ "$FILE" =~ [^a-zA-Z0-9_./:\ \-] ]]; then
    echo -e "${RED}Error: File path contains invalid characters${NC}"
    exit 1
fi

# Require a .md extension to avoid accidentally linting binary or config files.
if [[ "$FILE" != *.md ]]; then
    echo -e "${RED}Error: File must have a .md extension${NC}"
    exit 1
fi

# Confirm the file actually exists and is a regular file (not a directory).
if [ ! -f "$FILE" ]; then
    echo -e "${RED}Error: File not found: $FILE${NC}"
    exit 1
fi

# =============================================================================
# Validation checks
# =============================================================================
echo "Validating: $FILE"
echo "----------------------------------------"

# -----------------------------------------------------------------------------
# CHECK 1 — File ends with a newline
#
# POSIX defines a "text file" as a sequence of lines, each terminated by a
# newline character.  Files missing the final newline cause subtle bugs when
# tools concatenate or diff them.
#
# How it works:
#   tail -c 1  reads the very last byte of the file.
#   If that byte is a newline (\n), command substitution $(...) strips it,
#   leaving an empty string — so [ -n "" ] is false.
#   If the last byte is anything else (non-empty), we flag it.
# -----------------------------------------------------------------------------
if [ -n "$(tail -c 1 -- "$FILE")" ]; then
    warn "File does not end with a newline"
fi

# -----------------------------------------------------------------------------
# CHECK 2 — No trailing whitespace
#
# Trailing spaces are invisible in most editors but cause real problems:
#   • Two trailing spaces create a hard line break (<br>) in CommonMark
#   • They produce noisy, content-free diffs in version control
#
# grep ' $' matches any line whose last character is a space.
# -q suppresses output (we only want the exit code here);
# a separate non-quiet call collects the line numbers for the warning.
# -----------------------------------------------------------------------------
if grep -qn ' $' -- "$FILE" 2>/dev/null; then
    LINES=$(grep -n ' $' -- "$FILE" | cut -d: -f1 | tr '\n' ' ')
    warn "Trailing whitespace on lines: $LINES"
fi

# -----------------------------------------------------------------------------
# CHECK 3 — No hard tabs
#
# Markdown indentation should use spaces for portability.  Tabs are rendered
# with different widths across editors and break table and list alignment.
#
# $'\t' is Bash syntax for a literal tab character.
# -----------------------------------------------------------------------------
if grep -qn $'\t' -- "$FILE" 2>/dev/null; then
    LINES=$(grep -n $'\t' -- "$FILE" | cut -d: -f1 | tr '\n' ' ')
    warn "Hard tabs found on lines: $LINES"
fi

# -----------------------------------------------------------------------------
# CHECK 4 — Fenced code blocks have language identifiers
#
# A bare ``` with nothing after it disables syntax highlighting in every
# renderer.  Language identifiers also help linters and documentation
# generators understand the content.
#
# Pattern: ^```$ matches a line that is ONLY three backticks with no trailing
# language tag.  This catches both bare opening fences and closing fences
# that appear on their own line (closing fences are always bare by convention,
# so some false positives are expected — review the flagged lines).
# -----------------------------------------------------------------------------
if grep -qn '^```$' -- "$FILE" 2>/dev/null; then
    LINES=$(grep -n '^```$' -- "$FILE" | cut -d: -f1 | tr '\n' ' ')
    warn "Bare fenced code blocks (no language identifier) on lines: $LINES"
fi

# -----------------------------------------------------------------------------
# CHECK 5 — No three or more consecutive blank lines
#
# One blank line separates paragraphs; two is an accepted visual break between
# major sections.  Three or more is always accidental whitespace.
#
# -P  enables Perl-compatible regex (required for \n across line boundaries)
# -z  treats the file as a single NUL-delimited record (not line-by-line)
# -o  prints only the matching portion (prevents the whole file from dumping)
# \n\n\n+ matches three or more consecutive newlines.
# The inner `grep -q .` checks whether the outer grep produced any output.
# -----------------------------------------------------------------------------
if grep -Pzo '\n\n\n+' -- "$FILE" 2>/dev/null | grep -q .; then
    warn "Three or more consecutive blank lines found"
fi

# -----------------------------------------------------------------------------
# CHECK 6 — No Setext (underline-style) headers
#
# Setext headers look like:
#   My Heading
#   ==========
# or:
#   My Heading
#   ----------
#
# They are less grep-friendly, visually inconsistent with ATX (#), and are
# not supported by all markdown processors.  Use ATX style exclusively.
#
# Why not grep?
#   grep processes one line at a time, so a pattern containing \n (to match
#   the underline on the next line) never fires.  The original script used
#   grep -n '^[A-Za-z].*\n[=-]\+$' — that pattern silently matches nothing.
#
# awk solution:
#   We track the previous line in the variable `prev`.  When the current line
#   is entirely = or - characters (the underline) and prev is non-empty (the
#   heading text), we print the line number of the heading (NR-1).
# -----------------------------------------------------------------------------
SETEXT=$(awk '
    NR > 1 && /^[=\-]+$/ && prev != "" { print NR-1 }
    { prev = $0 }
' -- "$FILE")

if [ -n "$SETEXT" ]; then
    LINES=$(echo "$SETEXT" | tr '\n' ' ')
    warn "Setext (underline-style) headers on lines: $LINES — convert to ATX style (# Heading)"
fi

# -----------------------------------------------------------------------------
# CHECK 7 — Consistent list markers
#
# This project uses dash (-) for all unordered lists.  Mixing * and - in the
# same file is a style violation.  Using + is always flagged — it's unusual
# and nearly always accidental.
#
# grep -c returns the count of matching lines.  The "|| true" prevents
# set -euo pipefail from aborting when grep exits 1 (zero matches).
# -----------------------------------------------------------------------------
ASTERISK_COUNT=$(grep -c '^\* ' -- "$FILE" 2>/dev/null || true)
PLUS_COUNT=$(grep -c '^+ '     -- "$FILE" 2>/dev/null || true)
DASH_COUNT=$(grep -c '^- '     -- "$FILE" 2>/dev/null || true)

if [ "$ASTERISK_COUNT" -gt 0 ] && [ "$DASH_COUNT" -gt 0 ]; then
    warn "Mixed list markers (* and -) — $ASTERISK_COUNT asterisk lines, $DASH_COUNT dash lines"
fi
if [ "$PLUS_COUNT" -gt 0 ]; then
    warn "Plus (+) list markers found (prefer -) — $PLUS_COUNT occurrences"
fi

# -----------------------------------------------------------------------------
# CHECK 8 — Descriptive link text
#
# Links like [click here] or [here] carry no semantic meaning out of context
# and are inaccessible to screen-reader users who navigate by link list.
# Link text should describe the target content or action.
#
# -qi combines quiet mode (-q, only exit code) with case-insensitive (-i).
# -----------------------------------------------------------------------------
if grep -qi '\[click here\]' -- "$FILE" 2>/dev/null; then
    warn "'[click here]' links found — replace with descriptive anchor text"
fi
if grep -qi '\[here\]' -- "$FILE" 2>/dev/null; then
    warn "'[here]' links found — replace with descriptive anchor text"
fi

# -----------------------------------------------------------------------------
# CHECK 9 — Images have alt text
#
# ![](url) renders with no alt attribute.  Screen readers announce such images
# as simply "image" with no context.  Use ![meaningful description](url).
# -----------------------------------------------------------------------------
if grep -qn '!\[\](' -- "$FILE" 2>/dev/null; then
    LINES=$(grep -n '!\[\](' -- "$FILE" | cut -d: -f1 | tr '\n' ' ')
    warn "Images without alt text on lines: $LINES"
fi

# -----------------------------------------------------------------------------
# CHECK 10 — Emphasis style
#
# Prefer ** for bold and * for italic.  The underscore forms cause problems:
#   • _word_ inside a larger word (e.g. snake_case_identifier) triggers
#     emphasis unintentionally in some parsers
#   • Different parsers disagree on whether _ inside a word starts emphasis
#
# The italic check pipes through grep -v 'http' to skip lines containing URLs,
# since URLs naturally include underscores without meaning emphasis.  This is
# a heuristic — a perfect check would require full markdown parsing.
# -----------------------------------------------------------------------------
if grep -q '__[^_]*__' -- "$FILE" 2>/dev/null; then
    warn "Bold with __ found — prefer **bold**"
fi
if grep -v 'http' -- "$FILE" 2>/dev/null | grep -q '_[^_]*_'; then
    warn "Italic with _ found — prefer *italic*"
fi

# -----------------------------------------------------------------------------
# CHECK 11 — Unescaped angle-bracket placeholders (MD033)
#
# markdownlint rule MD033 (no-inline-html) flags any <word> pattern as inline
# HTML, even when the author meant a literal placeholder like <slug> or
# <your question>.
#
# Two correct escapes:
#   Prose / blockquotes:   \<word\>     (backslash escape)
#   Code-like identifiers: `<word>`     (inline code span)
#
# Algorithm:
#   1. Use awk to strip fenced code block lines from the file content.
#      Inside a fenced block, <tag> is perfectly valid and should not be
#      flagged.  The awk script toggles `in_fence` on each ``` line.
#   2. Search the remaining (non-fenced) text for <lowercase-word> patterns
#      using PCRE (-P flag, requires GNU grep).
#   3. Collect unique matches and report them.
#
# Limitation: inline code spans (single backticks within a line) are NOT
# excluded by this simplified approach.  A line like "run `<cmd>`" will
# appear in OUTSIDE_CODE and the `<cmd>` will be flagged even though it is
# already inside backticks.  Review flagged items manually before fixing.
#
# PCRE note: grep -P requires GNU grep.  On macOS use `ggrep` from Homebrew.
# -----------------------------------------------------------------------------
OUTSIDE_CODE=$(awk '
    /^```/ { in_fence = !in_fence; next }
    !in_fence { print }
' -- "$FILE")

if echo "$OUTSIDE_CODE" | grep -qP '<[a-z][a-z0-9_-]*>' 2>/dev/null; then
    MATCHES=$(echo "$OUTSIDE_CODE" | grep -oP '<[a-z][a-z0-9_-]*>' | sort -u | tr '\n' ' ')
    warn "Unescaped angle-bracket placeholders outside code blocks: $MATCHES"
    echo "       Fix: use \\<word\\> in prose, or \`<word>\` for code-like identifiers"
fi

# -----------------------------------------------------------------------------
# CHECK 12 — Table pipe spacing (MD060 — pipe style)
#
# Every table cell should have at least one space between its content and the
# surrounding pipe characters:
#   | cell content |    ← correct
#   |cell content|     ← incorrect: missing spaces on both sides
#
# Pattern explanation:
#   ^\|[^ :\-|]   — a line starting with | immediately followed by a character
#                   that is not a space, colon, dash, or pipe.  The colon and
#                   dash exclusions reduce false positives for separator rows
#                   like |:---|.
#
# This is a heuristic.  Separator rows (| --- | :---: |) may still be flagged
# if their dashes start right after the leading pipe.  Inspect flagged lines
# manually before applying a fix.
# -----------------------------------------------------------------------------
if grep -qnP '^\|[^ :\-|]' -- "$FILE" 2>/dev/null; then
    LINES=$(grep -nP '^\|[^ :\-|]' -- "$FILE" | cut -d: -f1 | tr '\n' ' ')
    warn "Table pipes may be missing surrounding spaces on lines: $LINES"
fi

# -----------------------------------------------------------------------------
# CHECK 13 — Table column alignment (MD060 — aligned style)
#
# In the "aligned" table style, every column must have identical width (in
# characters) across all rows so that pipe characters line up visually in a
# monospace editor.  When a cell is shorter than the max width for its column,
# it pushes subsequent pipes to the left, breaking alignment.
#
# Algorithm (implemented in awk for multi-line state tracking):
#
#   is_separator(line)
#     Returns 1 if the line contains only |, -, :, and spaces — the pattern
#     for a markdown table separator row (|---|, |:---:|, etc.).
#     Separator rows are excluded from the width comparison because their
#     dashes don't need to match content widths.
#
#   Accumulation phase (lines matching /^\|/)
#     For each table row, record its total character length and line number.
#
#   Comparison phase (triggered by any non-| line, or at EOF via END block)
#     Find the maximum length among non-separator rows.
#     Any non-separator row shorter than that maximum is misaligned — print
#     its line number.
#
#   Reset
#     Clear all per-table state so the next table starts fresh.
#     The END block handles tables that end at EOF (no trailing blank line).
#
# Fix strategy: recompute column widths using the PowerShell one-liner in
# the "Table Column Alignment (MD060)" section of SKILL.md, then paste the
# realigned table back into the file.
# -----------------------------------------------------------------------------
TABLE_ALIGN_ISSUES=$(awk '
function is_separator(line,   tmp) {
    tmp = line
    gsub(/[|:\- ]/, "", tmp)   # strip all separator-row characters
    return (tmp == "")          # if nothing remains, it is a separator row
}

/^\|/ {
    table_rows[++tbl_count] = length($0)
    table_lines[tbl_count]  = NR
    is_sep[tbl_count]       = is_separator($0)
    next
}

{
    # Non-table line — process the accumulated block, then reset
    if (tbl_count > 0) {
        max_len = 0
        for (i = 1; i <= tbl_count; i++)
            if (!is_sep[i] && table_rows[i] > max_len) max_len = table_rows[i]
        for (i = 1; i <= tbl_count; i++)
            if (!is_sep[i] && table_rows[i] < max_len) print table_lines[i]
        delete table_rows; delete table_lines; delete is_sep
        tbl_count = 0
    }
}

END {
    # Handle a table that ends at the last line of the file
    if (tbl_count > 0) {
        max_len = 0
        for (i = 1; i <= tbl_count; i++)
            if (!is_sep[i] && table_rows[i] > max_len) max_len = table_rows[i]
        for (i = 1; i <= tbl_count; i++)
            if (!is_sep[i] && table_rows[i] < max_len) print table_lines[i]
    }
}
' -- "$FILE")

if [ -n "$TABLE_ALIGN_ISSUES" ]; then
    LINES=$(echo "$TABLE_ALIGN_ISSUES" | sort -n | uniq | tr '\n' ' ')
    warn "Table columns not aligned (MD060) on lines: $LINES — repad cells to match widest row"
fi

# =============================================================================
# Summary
# =============================================================================
echo "----------------------------------------"
printf "Errors:   "
echo -e "${RED}${ERRORS}${NC}"
printf "Warnings: "
echo -e "${YELLOW}${WARNINGS}${NC}"

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}✓ No issues found${NC}"
    exit 0
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}! Completed with warnings${NC}"
    exit 0
else
    echo -e "${RED}✗ Validation failed${NC}"
    exit 1
fi

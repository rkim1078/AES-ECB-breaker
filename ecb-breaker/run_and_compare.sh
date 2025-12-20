#!/bin/sh
# run_and_compare.sh (POSIX /bin/sh)
# 1) Run decode_montecarlo.py
# 2) Line-level diff -> DIFF_OUT
# 3) Word-level diff (by index) -> WORD_DIFF_OUT (and wdiff-style if available)

set -eu

usage() {
  cat <<'USAGE'
Usage: ./run_and_compare.sh [options]

Options (defaults shown):
  -c, --cipher FILE       (default: tests/test1_ct.txt
  -d, --dict FILE         (default: tests/test1_dict.txt)
      --unigram FILE      (default: n-grams/unigram.csv)
      --bigram FILE       (default: n-grams/bigram.csv)
      --trigram FILE      (default: n-grams/trigram.csv)
  -o, --output FILE       (default: tests/test1_guess.txt)
  -e, --expected FILE     (default: test1_pt.txt)
  -D, --diff-out FILE     unified line diff file       (default: test1_diff.txt)
  -W, --word-diff-out FILE word-level diff file        (default: test1_wordiff.txt)
  -P, --program FILE      decoder entrypoint           (default: decode_montecarlo.py)
  -h, --help

Word diff details:
- If 'wdiff' is installed, we also include an inline marked version.
- Fallback always includes a unified diff over one-word-per-line with word indices.
USAGE
}

# Defaults
CIPHER="tests/test1_ct.txt"
DICT="tests/test1_dict.txt"
UNIGRAM="n-grams/unigram.csv"
BIGRAM="n-grams/bigram.csv"
TRIGRAM="n-grams/trigram.csv"
OUTPUT="test1_guess.txt"
EXPECTED="tests/test1_pt.txt"
DIFF_OUT="test1_diff.txt"
WORD_DIFF_OUT="test1_worddiff.txt"
PROGRAM="decode_montecarlo.py"
PY="python"

# Args
while [ "$#" -gt 0 ]; do
  case "$1" in
    -c|--cipher)   CIPHER="$2"; shift 2 ;;
    -d|--dict)     DICT="$2"; shift 2 ;;
    --unigram)     UNIGRAM="$2"; shift 2 ;;
    --bigram)      BIGRAM="$2"; shift 2 ;;
    --trigram)     TRIGRAM="$2"; shift 2 ;;
    -o|--output)   OUTPUT="$2"; shift 2 ;;
    -e|--expected) EXPECTED="$2"; shift 2 ;;
    -D|--diff-out) DIFF_OUT="$2"; shift 2 ;;
    -W|--word-diff-out) WORD_DIFF_OUT="$2"; shift 2 ;;
    -P|--program)  PROGRAM="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done
need_file() { [ -f "$1" ] || { echo "Missing file: $1" >&2; exit 1; }; }

# Normalize line endings and ensure exactly one trailing newline
normcopy() {
  in="$1"; out="$2"
  tmp="$(mktemp)"
  # 1) convert CRLF/CR -> LF
  tr -d '\r' < "$in" > "$tmp"
  # 2) ensure it ends with a newline
  if [ -s "$tmp" ]; then
    last_oct="$(tail -c1 "$tmp" 2>/dev/null | od -An -t o1 | tr -d ' ')"
    [ "$last_oct" = "012" ] || printf '\n' >> "$tmp"
  else
    # empty file — normalize to a single newline
    printf '\n' > "$tmp"
  fi
  mv "$tmp" "$out"
}

command -v "$PY" >/dev/null 2>&1 || { echo "Python not found: $PY" >&2; exit 1; }
need_file "$PROGRAM"; need_file "$CIPHER"; need_file "$DICT"
need_file "$UNIGRAM"; need_file "$BIGRAM"; need_file "$TRIGRAM"; need_file "$EXPECTED"

# Ensure output dirs
mdir() { [ "$1" = "." ] || mkdir -p "$1"; }
mdir "$(dirname -- "$OUTPUT")"
mdir "$(dirname -- "$DIFF_OUT")"
mdir "$(dirname -- "$WORD_DIFF_OUT")"

# Run decoder
echo "+ $PY $PROGRAM -c \"$CIPHER\" -d \"$DICT\" --unigram \"$UNIGRAM\" --bigram \"$BIGRAM\" --trigram \"$TRIGRAM\" -o \"$OUTPUT\""
set +e
"$PY" "$PROGRAM" -c "$CIPHER" -d "$DICT" --unigram "$UNIGRAM" --bigram "$BIGRAM" --trigram "$TRIGRAM" -o "$OUTPUT"
rc=$?
set -e
[ $rc -eq 0 ] || { echo "Decoder exited non-zero (rc=$rc)." >&2; exit $rc; }
[ -f "$OUTPUT" ] || { echo "Decoder did not produce output: $OUTPUT" >&2; exit 1; }




# Line-level diff


EXP_NORM="$(mktemp)"
OUT_NORM="$(mktemp)"
trap 'rm -f "$EXP_NORM" "$OUT_NORM"' EXIT INT TERM

normcopy "$EXPECTED" "$EXP_NORM"
normcopy "$OUTPUT"   "$OUT_NORM"

if ! diff -u --label "expected:$EXPECTED" --label "actual:$OUTPUT" "$EXP_NORM" "$OUT_NORM" > "$DIFF_OUT"; then
  echo "Differences found (line-level). See $DIFF_OUT"
else
  echo "No differences"
  echo "No differences." > "$DIFF_OUT"
  echo "Line-level match. Diff written to $DIFF_OUT"
fi

# Word-level diff (two outputs inside one file)
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' INT TERM EXIT

exp_words="$TMPDIR/expected.words"
out_words="$TMPDIR/output.words"

# Tokenize to one word per line (simple whitespace split; preserves punctuation attached to words)
tr -s '[:space:]' '\n' < "$EXPECTED" | sed '/^$/d' | nl -ba -w1 -s':' > "$exp_words"
tr -s '[:space:]' '\n' < "$OUTPUT"   | sed '/^$/d' | nl -ba -w1 -s':' > "$out_words"

{
  echo "=== WORD-LEVEL UNIFIED DIFF (indices are word positions) ==="
  if ! diff -u \
      --label "expected(words):$EXPECTED" \
      --label "actual(words):$OUTPUT" \
      "$exp_words" "$out_words"; then :; fi

  if command -v wdiff >/dev/null 2>&1; then
    echo ""
    echo "=== WDIFF INLINE (deletions=[- -], additions={+ +}) ==="
    # Show inline marked differences (no common text suppressed)
    # wdiff exit code is 1 if differences found; we don't treat that as an error.
    wdiff -n -w '[-' -x '-]' -y '{+' -z '+}' "$EXPECTED" "$OUTPUT" || true
  fi
} > "$WORD_DIFF_OUT"

# If empty, note no differences
[ -s "$WORD_DIFF_OUT" ] || echo "No word-level differences." > "$WORD_DIFF_OUT"

echo "Word-level diff written to $WORD_DIFF_OUT"


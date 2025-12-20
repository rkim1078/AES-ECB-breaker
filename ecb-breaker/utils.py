import argparse
import csv
import textwrap
from pathlib import Path
from typing import Dict, List, Any

# ---------- Basic loaders ----------

def load_lines(path: str) -> List[str]:
    """Read a file as a list of non-empty, stripped lines."""
    with open(path, "r", encoding="utf-8") as f:
        return [ln.strip() for ln in f if ln.strip()]

def load_wordlist(path: str) -> List[str]:
    """Alias for clarity: dictionary = one non-empty entry per line."""
    return load_lines(path)

def _auto_number(s: str) -> Any:
    """Coerce string to int or float if possible; otherwise return original string."""
    try:
        return int(s)
    except ValueError:
        try:
            return float(s)
        except ValueError:
            return s

def load_ngram_csv(path: str) -> Dict[str, Any]:
    """
    Load a CSV of n-gram stats.
    Expected rows: token,value
      - If only 'token' is present, value defaults to 1.
      - Trims whitespace; skips obvious header-like first cells.
    """
    out: Dict[str, Any] = {}
    header_like = {"token", "tokens", "ngram", "ngrams", "gram", "grams",
                   "char", "chars", "key", "keys", "count", "percentage", "percent"}
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        for row in reader:
            if not row:
                continue
            key = row[0].strip()
            if not key or key.lower() in header_like:
                continue
            if len(row) >= 3 and row[2].strip() != "":
                count_val = _auto_number(row[1].strip()) if row[1].strip() else 1
                pct_val = _auto_number(row[2].strip())
                out[key] = (count_val, pct_val)
            elif len(row) >= 2 and row[1].strip() != "":
                out[key] = (_auto_number(row[1].strip()),None)
            else:
                out[key] = (1,None)
    return out

# ---------- Helpers ----------

def format_ciphertext(cipher_list: List[str], width: int = 80, sep: str = " ") -> str:
    """
    Return the ciphertext list as a wrapped paragraph (no printing).
    Joins items with `sep` (default: space), then wraps to `width`.
    """
    paragraph = sep.join(cipher_list)
    return textwrap.fill(paragraph, width=width)


def pretty_print_ciphertext(cipher_list: List[str], width: int = 80, sep: str = "") -> None:
    """Print the wrapped ciphertext paragraph to stdout."""
    print(format_ciphertext(cipher_list, width=width, sep=sep))

def char_replace(cipher_list: List[str], old: str, new: str) -> List[str]:
    """Apply a simple .replace(old, new) to each list element."""
    return [s.replace(old, new) for s in cipher_list]

def write_text(path: str, text: str) -> None:
    """Write text to path, creating parent directories if needed."""
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")

# ---------- Argparse ----------

def parse_args():
    p = argparse.ArgumentParser(description="Load ciphertext (list), dictionary, and n-gram CSVs.")
    p.add_argument("-c", "--cipher", required=True,
                   help="Ciphertext file (loaded as a list: one non-empty line per item).")
    p.add_argument("-d", "--cipher-dict", dest="cipher_dict", required=True,
                   help="Dictionary file (one entry per line).")
    p.add_argument("--unigram", required=True, help="Unigram CSV (token,value).")
    p.add_argument("--bigram",  required=True, help="Bigram  CSV (token,value).")
    p.add_argument("--trigram", required=True, help="Trigram CSV (token,value).")
    p.add_argument("-o", "--output", help="If set, write decoded/pretty paragraph to this file.")
    p.add_argument("--width", type=int, default=80, help="Wrap width for paragraph (default: 80).")
    return p.parse_args()
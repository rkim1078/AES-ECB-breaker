# Monte Carlo ECB Decoder

## TL;DR
This project demonstrates a practical attack on ECB-encrypted text by reducing the problem to a substitution cipher and solving it with a Monte Carlo hill-climbing approach guided by English n-gram statistics (unigrams, bigrams, trigrams).

---

## Overview
- Language: Python  
- Domain: Applied cybersecurity & cryptography  
- Focus: Breaking poor/outdated cryptographic standards (ECB mode)  
- Techniques:  
  - Frequency analysis  
  - Stochastic optimization  
  - Monte Carlo method  
  - Hill climbing with n-gram scoring  

---

## Usage

### Automated Testing
Two helper scripts are provided:
- `run_and_compare.sh`: Runs a single test case and produces diffs.
- `test_locally.sh`: Runs all test cases in `./tests/` using `run_and_compare.sh`.

### Run All Tests
Linux:
```
./test_locally.sh
```

Git Bash:
```
bash ./test_locally.sh
```
- Runs all test cases in `./tests/`
- Produces:
  - A diff if decoded output differs from plaintext
  - A word-level diff for easier inspection

### Run a single test manually
Linux, Git Bash:
```
python decode_montecarlo.py \
  -c tests/test1_ct.txt \
  -d tests/test1_dict.txt \
  --unigram n-grams/unigram.csv \
  --bigram n-grams/bigram.csv \
  --trigram n-grams/trigram.csv \
  -o test1_guess.txt
```
- Output is written to `test1_guess.txt`
- See `/tests` for ciphertext, plaintext, and dictionaries

---

## Background: Why ECB Is Vulnerable
ECB (Electronic Codebook) mode encrypts each block independently and deterministically. Identical plaintext blocks always produce identical ciphertext blocks, [leaking patterns](https://github.com/robertdavidgraham/ecb-penguin).

Although originally standardized in [FIPS 81](https://csrc.nist.gov/files/pubs/fips/81/final/docs/fips81.pdf) (1980) and commonly used with DES, ECB was proven insecure by the 1990s. Even when paired with modern ciphers like AES, ECB remains vulnerable to frequency analysis and pattern leakage. Unfortunately, many legacy systems still use it.

This project demonstrates how those weaknesses can be exploited in practice.

---

## Attack Model & Assumptions

The attacker is assumed to have:
- Access to the ciphertext
- A dictionary of words appearing in the plaintext
- A single encryption key per message (i.e., ECB, not CTR or CBC)

---

## Approach
### 1. Frequency-Based Initialization
  - Ciphertext blocks are treated as symbols
  - The most frequent blocks are mapped to the most frequent English letters
  - This produces a rough initial substitution mapping

### 2. Reduce to a Substitution Cipher
  - The task becomes finding the correct mapping of 26 unique ciphertext symbols -> English letters
  - Brute-forcing all `26!` possibilities is infeasible

### 3. Monte Carlo Hill Climbing
  - Start from the frequency-based guess
  - Iteratively propose small random changes by swapping two letter assignments
  - Accept a change only if it improves the score

### 4. N-Gram Scoring
Candidate plaintexts are scored using English language statistics:
  - Unigrams (letter frequency)
  - Bigrams (e.g., "th", "er")
  - Trigrams (e.g., "the”, "ing")

A log-probability score is used to:
  - Avoid numerical underflow
  - Smooth the optimization landscape
  - Make score comparisons more stable

Higher scores indicate more "English-like" text.

---

## Convergence
- The algorithm runs for a fixed number of iterations (default: `2000`)
- Early iterations explore broadly
- Later iterations refine promising solutions
- With a good initial guess, convergence is fast (typically < 5s CPU time)

---

## Fin
This project shows how deterministic encryption + language statistics + stochastic optimization can break real-world systems. ECB's simplicity makes it dangerously predictable - and Monte Carlo methods are a powerful way to exploit that predictability.

---

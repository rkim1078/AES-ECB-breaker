## Overview
* Python, applied cybersecurity and cryptography
* Demonstration of breaking poor/outdated cryptographic standards
* Stochastic optimization for a deterministic solution
* Monte Carlo method, hill climbing

# Usage

`decode_montecarlo.py` can also be tested locally through `test_locally.sh` and `run_and_compare.sh`. `run_and_compare.sh` runs an individual test case, and `test_locally.sh` runs all `./tests/` for you through `run_and_compare.sh`. If desired, see `run_and_compare.sh` for more details on its usage.
For each test case, the scripts will output a diff file if there are any differences between plaintext and decoded ciphertext. It will also output a worddiff with differences on the word level.
Linux:
```
./test_locally.sh
```
Git Bash:
```
bash ./test_locally.sh
```

If desired, you can also use the following command to run `decode_montecarlo.py` (Linux, Git Bash):
```
python decode_montecarlo.py -c tests/test1_ct.txt -d tests/test1_dict.txt --unigram n-grams/unigram.csv --bigram n-grams/bigram.csv --trigram n-grams/trigram.csv -o test1_guess.txt
```
It should output the guess into `test1_guess.txt`. Refer to /tests for ciphertext, plaintext, and dictionary.



# Background - what is being shown
In 1980, [FIPS 81](https://csrc.nist.gov/files/pubs/fips/81/final/docs/fips81.pdf) detailed some of the earliest modes of operation, including ECB (Electronic Codebook) mode. ECB is a block cipher mode of operation, which provides confidentiality for a message by dividing it into fixed-size blocks, encrypting each block separately with a key. Notably, this is a deterministic algorithm, which, given the same key, will always encrypt a block of plaintext into the same block of ciphertext. Thus, one of ECB's largest failures is in its [leakage of patterns](https://github.com/robertdavidgraham/ecb-penguin) in encrypted data. Alongside DES (Data Encryption Standard), a symmetric key encryption algorithm, DES-ECB was one of the earliest forms of federal cybersecurity standards, becoming widespread in usage. By the 90s, however, both ECB and DES were proven to be cryptographically unsafe, and had seen practical attacks during this era.
Despite ECB's clear vulnerabilities and it no longer being federal standard, many legacy systems still use this mode of encryption. Even used with a modern encryption algorithm like [AES](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf), ECB is still vulnerable to a frequency analysis.
This project seeks to demonstrate a practical attack on ECB encrypted systems.

# Approach - rationale behind solution
This solution assumes we, the attacker, have access to the ciphertext and a dictionary of the words present in the plaintext, and that this ciphertext only generates one key per message (i.e. not other modes of operation like CTR).
We rely on generic English unigrams, bigrams, and trigrams, providing the frequency of 1-, 2-, 3-letter combinations of words to match the most common blocks of ciphertext to the most common unigrams, giving us a naive frequency-based mapping for some 0xAB0...9CC -> 'a', 0xD2F...3E8 -> 'b', etc.
Based on this initial guess, we can simplify the problem into solving a substitution cipher, where we must find the correct mapping of 26 unique blocks of ciphertext into English letters. Brute-forcing all 26! mappings is unrealistic, so we apply the Monte-Carlo method for the sake of optimization. In principle, this approach casts a smaller net, sampling all possible mappings by making random changes to our mapping, starting from our naive mapping. From this, we take a hill-climbing approach, deciding whether we keep or discard these incremental changes to our mapping depending on if this gives us a "better" solution. To determine what a better solution is, we also need a scoring algorithm that estimates how accurate a mapping is, or in other words how "English-like" the output of the mapping applied to the ciphertext is.
This scoring algorithm is an n‑gram-based scoring model to evaluate how plausible a candidate plaintext is. The concept behind the algorithm is that English text exhibits strong statistical regularities: certain letters appear more often than others, certain pairs of letters (like "th" or "er") appear far more frequently than random chance would suggest, and likewise for certain three-letter sequences ("the", "ing", "and"). By incorporating unigram, bigram, and trigram frequencies, we can assign a numerical score to any decoded text that reflects how closely it resembles real English. Higher scores indicate more linguistically plausible plaintext. We use a log-probability score to prevent numerical underflow when multiplying by small n-gram probabilities, and also to make our search landscape smoother -- that is, raw probabilities can vary in orders of magnitude, so log-score comparisons are mathematically equivalent to raw-score comparisons, but with a compressed and more managable search range.
With this scoring function in place, the Monte-Carlo search continually hill-climbs for a set number of iterations (default iter=2000). Each iteration proposes a small, random modification to the current substitution mapping by swapping the plaintext assignments of two ciphertext symbols. This produces a new candidate plaintext, which we score using the n-gram model. If the new score is higher, we accept the change because it moves us toward more English-like output.
Over many iterations, this stochastic hill-climbing process gradually improves the mapping. Early on, the algorithm accepts many changes and sees drastic changes in score, but as the score increases, the search naturally becomes more conservative, refining the mapping around promising regions of the search space as it hones in on the most English-likely mapping. Because the initial frequency-based guess already places the mapping near a plausible solution, the Monte-Carlo refinement converges relatively quickly toward the plaintext (in testing, <5s CPU time).
from __future__ import annotations
from typing import List

import random
import math
from collections import Counter

import utils


def load_files(args):
    cipher_list: List[str] = utils.load_lines(args.cipher)
    dict_list: List[str]   = utils.load_wordlist(args.cipher_dict)
    unigrams               = utils.load_ngram_csv(args.unigram)
    bigrams                = utils.load_ngram_csv(args.bigram)
    trigrams               = utils.load_ngram_csv(args.trigram)
    return cipher_list, dict_list, unigrams, bigrams, trigrams

def ngram_score(text: str, unigrams, bigrams, trigrams):
    """compute a log-probability score for text using n-gram frequencies"""
    score = 0.0
    for i in range(len(text)):
        unigram = text[i]
        if unigram in unigrams:
            score += math.log(float(unigrams[unigram][0])/100 + 1e-9)
        if i < len(text) - 1:
            bigram = text[i:i+2]
            if bigram in bigrams:
                score += math.log(float(bigrams[bigram][1])/100 + 1e-9)
        if i < len(text) - 2:
            trigram = text[i:i+3]
            if trigram in trigrams:
                score += math.log(float(trigrams[trigram][1])/100 + 1e-9)
    return score

def refine_mapping(cipher_list, mapping, unigrams, bigrams, trigrams, iters=2000):
    """refine substitution mapping using n-gram scoring and random swaps"""
    decoded = cipher_list[:]
    for ct, plain in mapping.items():
        decoded = utils.char_replace(decoded, ct, plain)
    best_text = "".join(decoded)
    best_score = ngram_score(best_text, unigrams, bigrams, trigrams)

    for _ in range(iters):
        a, b = random.sample(list(mapping.keys()), 2)
        new_mapping = mapping.copy()
        new_mapping[a], new_mapping[b] = new_mapping[b], new_mapping[a]

        new_decoded = cipher_list[:]
        for ct, plain in new_mapping.items():
            new_decoded = utils.char_replace(new_decoded, ct, plain)
        new_text = "".join(new_decoded)
        s = ngram_score(new_text, unigrams, bigrams, trigrams)
        if s > best_score:
            mapping, best_text, best_score = new_mapping, new_text, s
    return best_text

if __name__ == "__main__":
    args = utils.parse_args()
    cipher_list, DICT_LIST, UNIGRAMS, BIGRAMS, TRIGRAMS = load_files(args)

    freq = Counter(cipher_list)
    block_freq = freq.most_common(27)
    freq_ct_blocks = []
    for block_num in block_freq:
        block = block_num[0]
        freq_ct_blocks.append(block)

    ### UNIGRAMS, BIGRAMS, TRIGRAMS derived from csv input;
    ### csv with headers, "letter,percentage" or "ngram,count,percentage"
    ### the load_ngram_csv function does not account for "letter" header --
    ### see :53
    del UNIGRAMS['letter']
    
    freq_unigram_letters = [' '] + sorted(UNIGRAMS.keys(), key=lambda x: float(UNIGRAMS[x][0]), reverse=True)
    
    # build our naive frequency analysis: (ct_block, letter) kv pairs
    frequency_analysis = {}
    for i in range(len(freq_ct_blocks)):
        ct_block = freq_ct_blocks[i]
        letter = freq_unigram_letters[i]
        frequency_analysis[ct_block] = letter
    
    # hill-climb towards final mapping by increases in log-probability scoring
    decoded_text = refine_mapping(cipher_list, frequency_analysis, UNIGRAMS, BIGRAMS, TRIGRAMS, iters=3000)

    if args.output:
        utils.write_text(args.output, decoded_text)

    ## If you want to display on stdout
    #utils.pretty_print_ciphertext(decoded_text, width=args.width)


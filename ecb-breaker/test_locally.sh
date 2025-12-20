#!/bin/env bash

./run_and_compare.sh \
  -c tests/test1_ct.txt \
  -d tests/test1_dict.txt \
  --unigram n-grams/unigram.csv \
  --bigram n-grams/bigram.csv \
  --trigram n-grams/trigram.csv \
  -o tests/test1_guess.txt \
  -e tests/test1_pt.txt \
  -D test1_diff.txt


./run_and_compare.sh \
  -c tests/test2_ct.txt \
  -d tests/test2_dict.txt \
  --unigram n-grams/unigram.csv \
  --bigram n-grams/bigram.csv \
  --trigram n-grams/trigram.csv \
  -o tests/test2_guess.txt \
  -e tests/test2_pt.txt \
  -D test1_diff.txt \
  -W test2_worddiff.txt


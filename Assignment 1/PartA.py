import re
import sys
from collections import defaultdict

def tokenize(text_file_path):
    '''
    O(n)
    read file and extract token
    :param text_file_path:
    :return:
    '''
    try:
        with open(text_file_path, 'r', encoding = 'utf-8') as f:
            text = f.read()
        tokens = re.findall(r"\W?([a-z0-9]+)\W?", text.lower())
        return tokens
    except Exception as e:
        print(f"Error reading file {text_file_path}: {e}")
        return []

def compute_word_frequencies(tokens):
    '''
    Count occurrences of token
    O(n)
    :param tokens:
    :return:
    '''
    frequencies = defaultdict(int)
    for token in tokens:
        frequencies[token] += 1
    return dict(frequencies)

def print_word_frequencies(frequencies):
    '''
    Print token freq sort by count and alphabet
    O(n log n)
    :param frequencies:
    :return:
    '''
    sorted_tokens = sorted(frequencies.items(), key = lambda x: (-x[1], x[0]))
    for token, count in sorted_tokens:
        print(f"{token} -> {count}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python PartA.py <text_file_path>")
        sys.exit(1)

    text_file_path = sys.argv[1]
    tokens = tokenize(text_file_path)
    frequencies = compute_word_frequencies(tokens)
    print_word_frequencies(frequencies)
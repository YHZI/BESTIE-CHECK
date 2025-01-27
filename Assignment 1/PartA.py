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



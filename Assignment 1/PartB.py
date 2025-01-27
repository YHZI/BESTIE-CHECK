import sys
from PartA import tokenize


def compute_intersection(file1_path, file2_path):
    '''
    O(n+m)
    find num of common token of two file
    :param file1_path:
    :param file2_path:
    :return:
    '''
    try:
        tokens1 = set(tokenize(file1_path))
        tokens2 = set(tokenize(file2_path))
        intersection = tokens1 & tokens2
        return len(intersection)
    except Exception as e:
        print(f"Error processing files: {e}")
        return 0

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python PartB.py <file1_path> <file2_path>")
        sys.exit(1)

    file1_path = sys.argv[1]
    file2_path = sys.argv[2]
    common_count = compute_intersection(file1_path, file2_path)
    print(f"Number of common tokens: {common_count}")

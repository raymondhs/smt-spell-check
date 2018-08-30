import string
import sys

res = set()
for line in sys.stdin:
    line = line.strip()
    for word in line.split():
        if word.isalpha():
            word = " ".join(word)
            if word not in res:
                res.add(word)
                print(word)

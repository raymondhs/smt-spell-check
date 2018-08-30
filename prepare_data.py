import re
import sys

output_fn = sys.argv[1]

pairs = []
cur = None
while True:
    line = sys.stdin.readline()
    if not line:
        break
    line = line.strip().split()[0]
    if line[0] == '$': # the corrected word
        cur = line[1:]
    elif cur and cur != '?':
        # correct-misspelled pair
        pairs.append((cur,line))

with open(output_fn+'.cor', 'w') as f_cor, \
     open(output_fn+'.err', 'w') as f_err:
    for cor, err in pairs:
        # Split into characters
        f_cor.write(" ".join(cor)+'\n')
        f_err.write(" ".join(err)+'\n')

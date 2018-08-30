import sys

def has_symbols(word):
    return any(c in word for c in "0123456789.,/-\'\"")
    
output_fn = sys.argv[1]
f_cor = open(output_fn+".cor", "w")
f_err = open(output_fn+".err", "w")

cur = None
for line in sys.stdin:
    line = line.strip()
    if line.startswith("S "):
        cur = line[2:].split()
    if line.startswith("A "):
        info = line.split("|||")
        span = info[0].split()
        sid = int(span[1])
        eid = int(span[2])
        err_type = info[1]
        corr = info[2]
        if eid-sid != 1 \
            or err_type != "Mec" \
            or has_symbols(cur[sid]) \
            or has_symbols(corr):
            continue
        f_err.write(" ".join(cur[sid])+"\n")
        f_cor.write(" ".join(corr)+"\n")

f_err.close()
f_cor.close()

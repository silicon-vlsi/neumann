#!/usr/bin/env python3
# bin2hex.py <in.bin> <out.hex> : little-endian 32-bit words, one per line ($readmemh)
import sys
b = open(sys.argv[1], 'rb').read()
b += b'\0' * (-len(b) % 4)
with open(sys.argv[2], 'w') as f:
    for i in range(0, len(b), 4):
        f.write('%08x\n' % int.from_bytes(b[i:i+4], 'little'))

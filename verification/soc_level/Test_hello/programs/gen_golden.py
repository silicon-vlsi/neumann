#!/usr/bin/env python3
"""gen_golden.py - the answer key, computed by Python, not by our chip."""
import os
HERE = os.path.dirname(os.path.abspath(__file__))
answer = 5 + 7                                         # what hello.S must compute
with open(os.path.join(HERE, '..', 'golden', 'hello.golden'), 'w', newline='\n') as f:
    f.write('%08x\n' % answer)
print('golden: %d = 0x%08x' % (answer, answer))

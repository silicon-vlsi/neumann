#!/usr/bin/env python3
"""mkflash.py - pack an application into the SPI flash image read by the boot ROM.

usage: mkflash.py <iram.bin> <dram.bin> <flash.hex> [--entry 0x80000080]
                  [--corrupt magic|length|checksum]

flash layout (all words little-endian):
  0x00  header: magic 0x4D55454E ("NEUM"), iram_len, dram_len, entry, checksum, 0, 0, 0
  0x20  IRAM image (iram_len bytes)  -> copied to 0x8000_0000
        DRAM image (dram_len bytes)  -> copied to 0x8001_0040
  checksum = 32-bit sum of all IRAM and DRAM image words.
flash.hex: one byte per line (for $readmemh into spiflash.v, +firmware=flash.hex).
--corrupt makes a bad image on purpose (negative tests of the boot ROM).
"""
import argparse, struct

MAGIC = 0x4D55454E
IRAM_MAX, DRAM_MAX = 16384, 8192 - 64

def pad4(b):
    return b + b'\0' * (-len(b) % 4)

ap = argparse.ArgumentParser()
ap.add_argument('iram'); ap.add_argument('dram'); ap.add_argument('out')
ap.add_argument('--entry', default='0x80000080')
ap.add_argument('--corrupt', choices=['magic', 'length', 'checksum'])
a = ap.parse_args()

iram = pad4(open(a.iram, 'rb').read())
dram = pad4(open(a.dram, 'rb').read())
if len(iram) > IRAM_MAX or len(dram) > DRAM_MAX:
    raise SystemExit('image too big: iram %d (max %d), dram %d (max %d)'
                     % (len(iram), IRAM_MAX, len(dram), DRAM_MAX))
body = iram + dram
csum = sum(struct.unpack('<%dI' % (len(body) // 4), body)) & 0xFFFFFFFF
magic, ilen = MAGIC, len(iram)
if a.corrupt == 'magic':    magic ^= 1
if a.corrupt == 'length':   ilen += 2            # not a multiple of 4
if a.corrupt == 'checksum': csum = (csum + 1) & 0xFFFFFFFF
hdr = struct.pack('<8I', magic, ilen, len(dram), int(a.entry, 0), csum, 0, 0, 0)
img = hdr + body
with open(a.out, 'w') as f:
    for x in img:
        f.write('%02x\n' % x)
print('%s: %d bytes (iram %d, dram %d, entry %s, checksum %08x%s)'
      % (a.out, len(img), len(iram), len(dram), a.entry, csum,
         ', CORRUPT ' + a.corrupt if a.corrupt else ''))

#!/bin/bash
# run_verilator.sh - build, then simulate the SDC flash boot with Verilator 5.
#   good image (gcd, must match golden) + 3 bad images (must be rejected),
#   with CLK_GATING = 1 and 0.  Usage: ./run_verilator.sh [quick]
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../../.."
"$HERE/build.sh"
cd "$ROOT"; ROOT=$(pwd)
T=verification/soc_level/Test_via_sdc; B=$T/build
GATES="1 0"; [ "$1" = quick ] && GATES=1
pass=0; tot=0
for cg in $GATES; do
  O=$B/obj_cg$cg
  verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-MULTIDRIVEN -GCLK_GATING=$cg \
    --timescale 1ns/1ps --top-module tb_sdc_boot -f neumann_soc.f $T/flash/spiflash.v $T/tb/tb_sdc_boot.sv $ROOT/$T/tb/dpi_getenv.c \
    --Mdir $O -o sim > $O.log 2>&1 || { grep %Error $O.log | head; exit 1; }
  for t in pass:flash_gcd e1:flash_bad_magic e2:flash_bad_length e3:flash_bad_checksum; do
    tot=$((tot+1))
    out=$(./$O/sim +EXPECT=${t%%:*} +firmware=$B/${t#*:}.hex +ROM=$B/rom.hex +GOLDEN=$T/golden/gcd.golden)
    echo "$out" > $B/sim_cg${cg}_${t%%:*}.log
    echo "$out" | grep -E "BOOT_STATUS|program done|MISMATCH|ERROR|tb_sdc_boot|RESULT"
    echo "$out" | grep -q "RESULT: PASS" && pass=$((pass+1))
  done
done
echo "PASSED $pass / $tot"
[ $pass -eq $tot ]

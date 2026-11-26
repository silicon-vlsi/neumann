#!/bin/bash
# run_questa.sh - build, then simulate the SDC flash boot with Questa.
#   Usage: ./run_questa.sh [pass|e1|e2|e3] [gui]     (default: all four, batch)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../../.."
"$HERE/build.sh"
cd "$ROOT"; ROOT=$(pwd)
T=verification/soc_level/Test_via_sdc; B=$T/build
rm -rf $B/work; vlib $B/work
vlog -work $B/work -sv -timescale 1ns/1ps -f neumann_soc.f $T/flash/spiflash.v $T/tb/tb_sdc_boot.sv $T/tb/dpi_getenv.c \
  -suppress 2583 > $B/vlog.log || { tail -30 $B/vlog.log; exit 1; }
TESTS="pass e1 e2 e3"; [ -n "$1" ] && TESTS=$1
MODE="-c -do \"run -all; quit -f\""; [ "$2" = gui ] && MODE="-do \"add wave -r /tb_sdc_boot/*; run -all\""
declare -A IMG=([pass]=flash_gcd [e1]=flash_bad_magic [e2]=flash_bad_length [e3]=flash_bad_checksum)
pass=0; tot=0
for t in $TESTS; do
  tot=$((tot+1))
  eval vsim -work $B/work -voptargs=+acc tb_sdc_boot $MODE \
    +EXPECT=$t +firmware=$B/${IMG[$t]}.hex +ROM=$B/rom.hex +GOLDEN=$T/golden/gcd.golden \
    > $B/questa_$t.log 2>&1 || true
  grep -E "BOOT_STATUS|program done|MISMATCH|ERROR|tb_sdc_boot|RESULT" $B/questa_$t.log
  grep -q "RESULT: PASS" $B/questa_$t.log && pass=$((pass+1))
done
echo "PASSED $pass / $tot"
[ $pass -eq $tot ]

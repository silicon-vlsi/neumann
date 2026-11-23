#!/bin/bash
# build.sh - build the boot ROM and the gcd program, pack the SPI flash images.
# Run from anywhere. Uses riscv64-unknown-elf-gcc if found, else clang/lld.
# Output: build/rom.hex           boot ROM (also copied to ../../sw/boot/rom.hex)
#         build/gcd.elf/.dis      program
#         build/flash_gcd.hex     good flash image
#         build/flash_bad_{magic,length,checksum}.hex   negative-test images
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../.."
B="$HERE/build"; mkdir -p "$B"
ARCH="-march=rv32ic_zicsr -mabi=ilp32"
CF="-O2 -ffreestanding -fno-builtin -nostdlib -Wall -I$ROOT/sw/app -I$HERE/programs"
if command -v riscv64-unknown-elf-gcc >/dev/null; then
  P=riscv64-unknown-elf-
  CC="${P}gcc $ARCH"
  LINK() { ${P}gcc $ARCH -nostdlib -nostartfiles -Wl,--no-relax -T "$@"; }
  OBJCOPY=${P}objcopy; OBJDUMP=${P}objdump
  echo "toolchain: $(${P}gcc --version | head -1)"
else
  CC="clang --target=riscv32-unknown-elf $ARCH -mno-relax"
  LINK() { local lds=$1; shift; ld.lld -T "$lds" "$@"; }
  OBJCOPY=llvm-objcopy; OBJDUMP=llvm-objdump
  echo "toolchain: $(clang --version | head -1)"
fi

# boot ROM
$CC -c "$ROOT/sw/boot/rom.S" -o "$B/rom.o"
LINK "$ROOT/sw/boot/link_rom.ld" "$B/rom.o" -o "$B/rom.elf"
$OBJCOPY -O binary "$B/rom.elf" "$B/rom.bin"
python3 "$ROOT/sw/bin2hex.py" "$B/rom.bin" "$B/rom.hex"
cp "$B/rom.hex" "$ROOT/sw/boot/rom.hex"

# gcd program: inputs + golden, compile, split into IRAM / DRAM binaries
python3 "$HERE/programs/gen_gcd.py"
$CC -c "$ROOT/sw/app/start.S" -o "$B/start.o"
$CC $CF -c "$HERE/programs/gcd.c" -o "$B/gcd.o"
LINK "$ROOT/sw/app/link_app.ld" "$B/start.o" "$B/gcd.o" -o "$B/gcd.elf"
$OBJDUMP -d "$B/gcd.elf" > "$B/gcd.dis"
$OBJCOPY -O binary --only-section=.vectors --only-section=.text "$B/gcd.elf" "$B/gcd_iram.bin"
$OBJCOPY -O binary --only-section=.data "$B/gcd.elf" "$B/gcd_dram.bin"

# flash images
M="python3 $HERE/tools/mkflash.py $B/gcd_iram.bin $B/gcd_dram.bin"
$M "$B/flash_gcd.hex"
for c in magic length checksum; do $M "$B/flash_bad_$c.hex" --corrupt $c; done

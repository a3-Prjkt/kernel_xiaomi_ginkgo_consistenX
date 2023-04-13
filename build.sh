#!/bin/bash

# Script for compiling Cons!stenX Kernel
# Copyright (c) 2022 Disconnect0 <forestd.github@gmail.com>
# Based on ghostrider-reborn script
# Copyright (C) 2020-2021 Adithya R.

# Variables
SECONDS=0 # builtin bash timer
ZIPNAME="CIsX~Nethunter-Ginkgo|Willow-$(TZ=Asia/Manila date +"%Y%m%d-%H%M").zip"
if ! [ $USER = "gitpod" ]; then
TC_DIR="$HOME/tc/a3-clang"
else
TC_DIR="/workspace/tc/a3-clang"
fi
AK3_DIR="./ak3"
DEFCONFIG="vendor/ginkgo-perf_defconfig"

export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
echo "Æ3 clang not found! Cloning to $TC_DIR..."
if ! git clone -q -b 16.x --depth=1 https://gitlab.com/a3-Prjkt/a3-clang $TC_DIR; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

echo -e "\nCompiling with $($TC_DIR/bin/clang --version | head -n1 | cut -d " " -f1,4)\n"

export KBUILD_BUILD_USER=forest
export KBUILD_BUILD_HOST=Disconnect0
export KBUILD_BUILD_VERSION="1"

if [[ $1 = "-r" || $1 = "--regen" ]]; then
make O=out ARCH=arm64 $DEFCONFIG savedefconfig
cp out/defconfig arch/arm64/configs/$DEFCONFIG
exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
rm -rf out
fi

if [[ $1 = "--update-wireguard" ]]; then
set -e
USER_AGENT="WireGuard-AndroidROMBuild/0.3 ($(uname -a))"

exec 9>.wireguard-fetch-lock
flock -n 9 || exit 0

[[ $(( $(date +%s) - $(stat -c %Y "net/wireguard/.check" 2>/dev/null || echo 0) )) -gt 86400 ]] || exit 0

while read -r distro package version _; do
	if [[ $distro == upstream && $package == linuxcompat ]]; then
		VERSION="$version"
		break
	fi
done < <(curl -A "$USER_AGENT" -LSs --connect-timeout 30 https://build.wireguard.com/distros.txt)

[[ -n $VERSION ]]

if [[ -f net/wireguard/version.h && $(< net/wireguard/version.h) == *$VERSION* ]]; then
	touch net/wireguard/.check
	exit 0
fi

rm -rf net/wireguard
mkdir -p net/wireguard
curl -A "$USER_AGENT" -LsS --connect-timeout 30 "https://git.zx2c4.com/wireguard-linux-compat/snapshot/wireguard-linux-compat-$VERSION.tar.xz" | tar -C "net/wireguard" -xJf - --strip-components=2 "wireguard-linux-compat-$VERSION/src"
sed -i 's/tristate/bool/;s/default m/default y/;' net/wireguard/Kconfig
touch net/wireguard/.check
fi

# Compilation
mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- Image.gz-dtb dtbo.img

# Checking Files
if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
echo -e "\nCompiled Successfully With $($TC_DIR/bin/clang --version | head -n1 | cut -d " " -f1,4)! Zipping up...\n"

# Zipping
if [ -d "$AK3_DIR" ]; then
cp -r $AK3_DIR AnyKernel3
echo -e "\nAnyKernel3 not found inside the repo! Aborting..."
fi
cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
cp out/arch/arm64/boot/dtbo.img AnyKernel3
rm -f *zip
cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
cd ..
rm -rf AnyKernel3
rm -rf out/arch/arm64/boot
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "Zip: $ZIPNAME"
if ! [[ $HOSTNAME = "KOMPUTERTWU" && $USER = "forest" ]]; then

# Uploading
curl -T $ZIPNAME temp.sh; echo
echo " "
curl --upload-file $ZIPNAME https://transfer.sh/$ZIPNAME; echo
fi
else
echo -e "\nCompilation failed!"
fi
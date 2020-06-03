#!/usr/bin/env bash

git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/x86/x86_64-linux-android-4.9
cd x86_64-linux-android-4.9
git checkout pie-b4s4-release
export PATH=$PATH:$(pwd)/bin
cd ..

git clone https://github.com/akonovalenkov/android-goldfish.git
cd android-goldfish
export CROSS_COMPILE=x86_64-linux-android-
export ARCH=x86_64
make x86_64_ranchu_defconfig
echo CONFIG_IKHEADERS=m >> .config
make -j$(nproc --all)
cd ..

sdkmanager --install "system-images;android-29;default;x86_64"
echo "no" | avdmanager create avd --name "test-bcc" --package "system-images;android-29;default;x86_64"
nohup emulator @test-bcc -partition-size 5120 -kernel ./android-goldfish/arch/x86/boot/bzImage &

until adb root
do
    echo waiting for adb root...
    sleep 1
done

git clone https://github.com/joelagnel/adeb.git
cd adeb
sed -i 's/ftp.us.debian.org/ftp.se.debian.org/g' buildstrap
./adeb prepare --bcc --build --arch amd64

cd ..
adb push android-goldfish/kernel/kheaders.ko /data
adb shell insmod /data/kheaders.ko

cd ./adeb

until ./adeb shell apt update
do
    echo trying apt update...
    sleep 1
done

until ./adeb shell apt install xz-utils
do
    echo trying installing requred packages...
    sleep 1
done

./adeb shell /usr/share/bcc/tools/syscount -d 5

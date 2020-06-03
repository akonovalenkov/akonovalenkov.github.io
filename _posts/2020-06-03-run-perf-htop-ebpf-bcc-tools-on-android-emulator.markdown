---
layout: post
title:  "Run perf, htop, eBPF BCC tools on android emulator"
date:   2020-06-03 10:11:43 +0200
categories: android
excerpt: Running standard linux tools and epbf bcc on android is not an easy task. This post contains complete guide and a full bash script for that.
---

[`eBPF`](
http://www.brendangregg.com/blog/2019-01-01/learn-ebpf-tracing.html
) is a safe in-kernel virtual machine which can be used to trace interactions between user space programs and linux kernel. 

The main advatage of `eBPF` over existing tools like `strace` or `perf trace` is low overhead. Since the `eBPF` instructions run in kernel there is no raw data transfer between user space and kernel.

eBPF is too low level to use directly, so a tooling was built around it - [BCC](https://github.com/iovisor/bcc).

> BCC is a toolkit for creating efficient kernel tracing and manipulation programs, and includes several useful tools and examples. It makes use of extended BPF (Berkeley Packet Filters), formally known as eBPF

This post will show how to run linux standard tools and `BCC` tools on an android emulator.

To run linux tools on android we need to create a linux environment. There is a project called [`adeb`](https://github.com/joelagnel/adeb) which does exactly that.

But if you clone `adeb`, follow all the instructions and try to run a bcc tool, you might get an error like following:

{%- highlight bash -%}
root@localhost:/usr/share/bcc/tools# cd /usr/share/bcc/tools/
root@localhost:/usr/share/bcc/tools# ./opensnoop
libbpf: failed to find valid kernel BTF
libbpf: vmlinux BTF is not found
sh: modprobe: command not found
Unable to find kernel headers. Try rebuilding kernel with CONFIG_IKHEADERS=m (module)
chdir(/lib/modules/4.14.112+/build): No such file or directory
Traceback (most recent call last):
  File "./opensnoop", line 236, in <module>
    b = BPF(text=bpf_text)
  File "/usr/lib/python2.7/dist-packages/bcc/__init__.py", line 357, in __init__
    raise Exception("Failed to compile BPF module %s" % (src_file or "<text>"))
Exception: Failed to compile BPF module <text>
{%- endhighlight -%}

Let's check what is going on:
{%- highlight bash -%}
root@localhost:/usr/share/bcc/tools# strace -f ./opensnoop
# ...
stat("/tmp/kheaders-4.14.112+", 0x7fff0fca6130) = -1 ENOENT (No such file or directory)
stat("/sys/kernel/kheaders.tar.xz", 0x7fff0fca60a0) = -1 ENOENT (No such file or directory)
[pid  3623] execve("/bin/sh", ["sh", "-c", "modprobe kheaders"], 0x7fff0fca7a00 /* 26 vars */) = 0
# ...
{%- endhighlight -%}

It tries to find kernel headers and gets `-1` meaning that the headers are not found. Then it tries to manually load a kernel module called `kheaders`. But neither `modprobe` is found on `$PATH`, no kheaders module exists.

We need to build a linux kernel with kheaders module. If you don't want to bother with the go through process - just jump straight to the [script](#the-script) down the page.

Clone and prepare required prebuilts:

{%- highlight bash -%}
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/x86/x86_64-linux-android-4.9
cd x86_64-linux-android-4.9
git checkout pie-b4s4-release
export PATH=$PATH:$(pwd)/bin
cd ..
{%- endhighlight -%}

Clone and build a linux kernel with `CONFIG_IKHEADERS` support. Thanks Mr. Ayrx on github.
{%- highlight bash -%}
git clone https://github.com/akonovalenkov/android-goldfish.git
cd android-goldfish
export CROSS_COMPILE=x86_64-linux-android-
export ARCH=x86_64
make x86_64_ranchu_defconfig
echo CONFIG_IKHEADERS=m >> .config
make -j$(nproc --all)
cd ..
{%- endhighlight -%}

Prepare and run an emulator (assumed android sdk installed), specifying the newly built kernel:

{%- highlight bash -%}
sdkmanager --install "system-images;android-29;default;x86_64"
echo "no" | avdmanager create avd --name "test-bcc" --package "system-images;android-29;default;x86_64"
nohup emulator @test-bcc -partition-size 5120 -kernel ./android-goldfish/arch/x86/boot/bzImage &
{%- endhighlight -%}

It's a good idea to warm up `adb root` before going to the next step:
{%- highlight bash -%}
until adb root
do
    echo waiting for adb root...
    sleep 1
done
{%- endhighlight -%}


Clone and prepare a shell environment with `adeb`. Make sure to use local mirror for debian packages. The hardcoded value is `us`.
When the preparation is done it will be possible to install standard linux tools like htop and perf.

{%- highlight bash -%}
git clone https://github.com/joelagnel/adeb.git
cd adeb
sed -i 's/ftp.us.debian.org/ftp.se.debian.org/g' buildstrap
./adeb prepare --bcc --build --arch amd64
cd ..
{%- endhighlight -%}

Push `kheaders.ko` kernel module to the emulator and install it:

{%- highlight bash -%}
adb push android-goldfish/kernel/kheaders.ko /data
adb shell insmod /data/kheaders.ko
{%- endhighlight -%}

We have to install `xz-utils` package on the emulator. In my experience there might be several transient errors like DNS or other network related problems, so let's add some retry logic:

{%- highlight bash -%}
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
{%- endhighlight -%}

And eventually we can run `BCC` tools:

{%- highlight bash -%}
./adeb shell /usr/share/bcc/tools/syscount -d 5
Tracing syscalls, printing top 10... Ctrl+C to quit.

SYSCALL                   COUNT
clock_gettime              8467
futex                      4747
ioctl                      1448
recvfrom                   1221
read                       1024
epoll_pwait                 909
write                       558
sendto                      509
getuid                      352
nanosleep                   281

Detaching...
{%- endhighlight -%}

## The script

Make sure to use your local mirror for debian packages.


{%- highlight bash  -%}
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

{%- endhighlight -%}

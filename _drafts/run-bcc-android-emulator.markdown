---
layout: post
title:  "Running perf, htop, eBPF BCC tools on android emulator. Complete guide"
date:   2020-05-27 13:11:43 +0200
categories: jekyll update
---

[eBPF](
http://www.brendangregg.com/blog/2019-01-01/learn-ebpf-tracing.html
) is a safe in-kernel virtual machine which can be used to trace interactions between user space programs and linux kernel. 

The main advatage of `eBPF` over existing tools like `strace` or `perf trace` is low overhead. Since the `eBPF` instructions run in kernel there is no raw data transfer between user space and kernel.

eBPF is too low level to use directly, so a tooling was built around it - [BCC](https://github.com/iovisor/bcc).

> BCC is a toolkit for creating efficient kernel tracing and manipulation programs, and includes several useful tools and examples. It makes use of extended BPF (Berkeley Packet Filters), formally known as eBPF

This post will show how to run linux standard tools and `BCC` tools on an android emulator.

Create and run an emulator (assumed android sdk installed):

{%- highlight bash -%}
avdmanager create avd --name "test-bcc" \
--package "system-images;android-29;default;x86_64"
#Do you wish to create a custom hardware profile? [no] no
emulator @test-bcc -partition-size 5120 &
{%- endhighlight -%}

Use a project [adeb](https://github.com/joelagnel/adeb) to install a chroot environment on emulator:

{%- highlight bash -%}
git clone https://github.com/joelagnel/adeb.git
cd adeb
{%- endhighlight -%}

Change package source url depending on your location:
{%- highlight bash -%}
vim buildstrap
:%s/ftp.us.debian.org/ftp.se.debian.org/g
# se - Sweden
{%- endhighlight -%}

Make the envinroment:
{%- highlight bash -%}
./adeb prepare --bcc --build --arch amd64
# INFO    : All done! Run "adeb shell" to enter environment
{%- endhighlight -%}

Enter the environment:
{%- highlight bash -%}
./adeb shell

##########################################################
# Welcome to androdeb environment running on Android!    #
# Questions to: Joel Fernandes <joel@joelfernandes.org>  #
                                                         #
 Try running vim, gcc, clang, git, make, perf, filetop   #
  ..etc or apt-get install something.                    #
##########################################################

root@localhost:/#
{%- endhighlight -%}


Install strace, perf, htop and others:

{%- highlight bash -%}
root@localhost:/# apt update
root@localhost:/# apt install strace linux-perf htop
{%- endhighlight -%}


Run BCC tools:
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

Here is a problem with lacking kernel headers. We need to build a custom kernel with headers support. Thanks to Mr. Ayrx on github we can just clone a repo:

{%- highlight bash -%}
# assuming in ./adeb folder
cd ..
git clone https://github.com/akonovalenkov/android-goldfish.git
{%- endhighlight -%}

We also need some additional tooling:

{%- highlight bash -%}
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/x86/x86_64-linux-android-4.9
cd x86_64-linux-android-4.9
git checkout pie-b4s4-release
cd ..
{%- endhighlight -%}

Build the kernel:

{%- highlight bash -%}
cd android-goldfish
export CROSS_COMPILE=x86_64-linux-android-
export ARCH=x86_64
export PATH=$PATH:$(pwd)/../x86_64-linux-android-4.9/bin
make x86_64_ranchu_defconfig
# set CONFIG_IKHEADERS=m in .config
echo CONFIG_IKHEADERS=m >> .config
make -j4 # 4 - number of cpu cores
# Kernel: arch/x86/boot/bzImage is ready
{%- endhighlight -%}







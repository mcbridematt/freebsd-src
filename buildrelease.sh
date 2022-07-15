#!/bin/sh
set +e
make clean
make buildkernel buildworld KERNCONF=GENERIC -j4
cd release
make obj -j4
make vm-image KERNCONF=GENERIC WITH_VMIMAGES=1 VMFORMATS="qcow2" NOSRC=1 NOPORTS=1 SWAPSIZE=4G
#make install DESTDIR=/var/freebsd-snapshot


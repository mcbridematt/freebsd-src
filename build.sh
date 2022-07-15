#!/bin/sh
set +e
make cleankernel KERNCONF=GENERIC
make buildkernel KERNCONF=GENERIC -j4
rm -rf /tmp/ten64kernel
make distributekernel KERNCONF=GENERIC DESTDIR=/tmp/ten64kernel
tar -C /tmp/ten64kernel/kernel/boot -cvf ten64kernel.tar kernel


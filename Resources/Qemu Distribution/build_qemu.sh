#!/bin/zsh

cd ~/Downloads

mkdir qemu
cd qemu

echo "Cloning Qemu..."
git clone https://github.com/qemu/qemu
cd qemu
git checkout v6.1.0

echo "Installing dependencies..."
brew install libffi gettext pkg-config autoconf automake pixman

echo "Compiling..."
mkdir build
cd build
../configure --target-list=arm-softmmu,aarch64-softmmu,x86_64-softmmu,i386-softmmu,ppc-softmmu,ppc64-softmmu,m68k-softmmu --enable-cocoa --enable-hvf --disable-gnutls
make -j8

cd ~/Downloads/qemu
mkdir dist

echo "Staging binaries into dist..."

cp qemu/build/qemu-system-arm dist/qemu-system-arm
cp qemu/build/qemu-system-aarch64 dist/qemu-system-aarch64
cp qemu/build/qemu-system-x86_64 dist/qemu-system-x86_64
cp qemu/build/qemu-system-i386 dist/qemu-system-i386
cp qemu/build/qemu-system-ppc dist/qemu-system-ppc
cp qemu/build/qemu-system-ppc64 dist/qemu-system-ppc64
cp qemu/build/qemu-system-m68k dist/qemu-system-m68k
cp qemu/build/qemu-img dist/qemu-img

cd dist
mkdir Libs

cp /usr/local/opt/libusb/lib/libusb-1.0.0.dylib Libs/libusb-1.0.0.dylib
cp /usr/local/opt/pixman/lib/libpixman-1.0.dylib Libs/libpixman-1.0.dylib
cp /usr/local/opt/glib/lib/libgthread-2.0.0.dylib Libs/libgthread-2.0.0.dylib
cp /usr/local/opt/glib/lib/libglib-2.0.0.dylib Libs/libglib-2.0.0.dylib
cp /usr/local/opt/glib/lib/libgio-2.0.0.dylib Libs/libgio-2.0.0.dylib
cp /usr/local/opt/glib/lib/libgobject-2.0.0.dylib Libs/libgobject-2.0.0.dylib
cp /usr/local/opt/gettext/lib/libintl.8.dylib  Libs/libintl.8.dylib
cp /usr/local/opt/glib/lib/libgmodule-2.0.0.dylib Libs/libgmodule-2.0.0.dylib
cp /usr/local/opt/pcre/lib/libpcre.1.dylib Libs/libpcre.1.dylib
cp /usr/local/opt/libffi/lib/libffi.7.dylib Libs/libffi.7.dylib

echo "Installing pc-bios..."
mkdir pc-bios

cd ~/Downloads/qemu

cp qemu/build/pc-bios/edk2-aarch64-code.fd dist/pc-bios
cp qemu/build/pc-bios/edk2-arm-code.fd dist/pc-bios
cp qemu/build/pc-bios/edk2-arm-vars.fd dist/pc-bios
cp qemu/build/pc-bios/edk2-i386-code.fd dist/pc-bios
cp qemu/build/pc-bios/edk2-i386-secure-code.fd dist/pc-bios
cp qemu/build/pc-bios/edk2-i386-vars.fd dist/pc-bios
cp qemu/build/pc-bios/edk2-x86_64-code.fd dist/pc-bios
cp qemu/build/pc-bios/edk2-x86_64-secure-code.fd dist/pc-bios
cp qemu/build/pc-bios/keymaps/ar dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/bepo dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/cz dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/da dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/de dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/de-ch dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/en-gb dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/en-us dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/es dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/et dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/fi dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/fo dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/fr dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/fr-be dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/fr-ca dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/fr-ch dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/hr dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/hu dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/is dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/it dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/ja dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/lt dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/lv dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/mk dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/nl dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/no dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/pl dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/pt dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/pt-br dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/ru dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/th dist/pc-bios/keymaps
cp qemu/build/pc-bios/keymaps/tr dist/pc-bios/keymaps
cp qemu/pc-bios/bios.bin dist/pc-bios
cp qemu/pc-bios/bios-256k.bin dist/pc-bios
cp qemu/pc-bios/bios-microvm.bin dist/pc-bios
cp qemu/pc-bios/qboot.rom dist/pc-bios
cp qemu/pc-bios/sgabios.bin dist/pc-bios
cp qemu/pc-bios/vgabios.bin dist/pc-bios
cp qemu/pc-bios/vgabios-cirrus.bin dist/pc-bios
cp qemu/pc-bios/vgabios-stdvga.bin dist/pc-bios
cp qemu/pc-bios/vgabios-vmware.bin dist/pc-bios
cp qemu/pc-bios/vgabios-qxl.bin dist/pc-bios
cp qemu/pc-bios/vgabios-virtio.bin dist/pc-bios
cp qemu/pc-bios/vgabios-ramfb.bin dist/pc-bios
cp qemu/pc-bios/vgabios-bochs-display.bin dist/pc-bios
cp qemu/pc-bios/vgabios-ati.bin dist/pc-bios
cp qemu/pc-bios/openbios-sparc32 dist/pc-bios
cp qemu/pc-bios/openbios-sparc64 dist/pc-bios
cp qemu/pc-bios/openbios-ppc dist/pc-bios
cp qemu/pc-bios/QEMU,tcx.bin dist/pc-bios
cp qemu/pc-bios/QEMU,cgthree.bin dist/pc-bios
cp qemu/pc-bios/pxe-e1000.rom dist/pc-bios
cp qemu/pc-bios/pxe-eepro100.rom dist/pc-bios
cp qemu/pc-bios/pxe-ne2k_pci.rom dist/pc-bios
cp qemu/pc-bios/pxe-pcnet.rom dist/pc-bios
cp qemu/pc-bios/pxe-rtl8139.rom dist/pc-bios
cp qemu/pc-bios/pxe-virtio.rom dist/pc-bios
cp qemu/pc-bios/efi-e1000.rom dist/pc-bios
cp qemu/pc-bios/efi-eepro100.rom dist/pc-bios
cp qemu/pc-bios/efi-ne2k_pci.rom dist/pc-bios
cp qemu/pc-bios/efi-pcnet.rom dist/pc-bios
cp qemu/pc-bios/efi-rtl8139.rom dist/pc-bios
cp qemu/pc-bios/efi-virtio.rom dist/pc-bios
cp qemu/pc-bios/efi-e1000e.rom dist/pc-bios
cp qemu/pc-bios/efi-vmxnet3.rom dist/pc-bios
cp qemu/pc-bios/qemu-nsis.bmp dist/pc-bios
cp qemu/pc-bios/bamboo.dtb dist/pc-bios
cp qemu/pc-bios/canyonlands.dtb dist/pc-bios
cp qemu/pc-bios/petalogix-s3adsp1800.dtb dist/pc-bios
cp qemu/pc-bios/petalogix-ml605.dtb dist/pc-bios
cp qemu/pc-bios/multiboot.bin dist/pc-bios
cp qemu/pc-bios/linuxboot.bin dist/pc-bios
cp qemu/pc-bios/linuxboot_dma.bin dist/pc-bios
cp qemu/pc-bios/kvmvapic.bin dist/pc-bios
cp qemu/pc-bios/pvh.bin dist/pc-bios
cp qemu/pc-bios/s390-ccw.img dist/pc-bios
cp qemu/pc-bios/s390-netboot.img dist/pc-bios
cp qemu/pc-bios/slof.bin dist/pc-bios
cp qemu/pc-bios/skiboot.lid dist/pc-bios
cp qemu/pc-bios/palcode-clipper dist/pc-bios
cp qemu/pc-bios/u-boot.e500 dist/pc-bios
cp qemu/pc-bios/u-boot-sam460-20100605.bin dist/pc-bios
cp qemu/pc-bios/qemu_vga.ndrv dist/pc-bios
cp qemu/pc-bios/edk2-licenses.txt dist/pc-bios
cp qemu/pc-bios/hppa-firmware.img dist/pc-bios
cp qemu/pc-bios/opensbi-riscv32-generic-fw_dynamic.bin dist/pc-bios
cp qemu/pc-bios/opensbi-riscv64-generic-fw_dynamic.bin dist/pc-bios
cp qemu/pc-bios/opensbi-riscv32-generic-fw_dynamic.elf dist/pc-bios
cp qemu/pc-bios/opensbi-riscv64-generic-fw_dynamic.elf dist/pc-bios
cp qemu/pc-bios/npcm7xx_bootrom.bin dist/pc-bios
cp qemu/build/pc-bios/descriptors/50-edk2-i386-secure.json dist/pc-bios/firmware
cp qemu/build/pc-bios/descriptors/50-edk2-x86_64-secure.json dist/pc-bios/firmware
cp qemu/build/pc-bios/descriptors/60-edk2-aarch64.json dist/pc-bios/firmware
cp qemu/build/pc-bios/descriptors/60-edk2-arm.json dist/pc-bios/firmware
cp qemu/build/pc-bios/descriptors/60-edk2-i386.json dist/pc-bios/firmware
cp qemu/build/pc-bios/descriptors/60-edk2-x86_64.json dist/pc-bios/firmware
cp qemu/pc-bios/keymaps/sl dist/pc-bios/keymaps
cp qemu/pc-bios/keymaps/sv dist/pc-bios/keymaps

echo "Fixing dependencies for qemu-system-arm"
cd ~/Downloads/qemu/dist

install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/Libs/libusb-1.0.0.dylib qemu-system-arm
install_name_tool -change /usr/local/opt/pixman/lib/libpixman-1.0.dylib @executable_path/Libs/libpixman-1.0.dylib qemu-system-arm
install_name_tool -change /usr/local/opt/glib/lib/libgthread-2.0.0.dylib @executable_path/Libs/libgthread-2.0.0.dylib qemu-system-arm
install_name_tool -change /usr/local/opt/glib/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib qemu-system-arm
install_name_tool -change /usr/local/opt/glib/lib/libgio-2.0.0.dylib @executable_path/Libs/libgio-2.0.0.dylib qemu-system-arm
install_name_tool -change /usr/local/opt/glib/lib/libgobject-2.0.0.dylib @executable_path/Libs/libgobject-2.0.0.dylib qemu-system-arm
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib qemu-system-arm
install_name_tool -change /usr/local/opt/glib/lib/libgmodule-2.0.0.dylib @executable_path/Libs/libgmodule-2.0.0.dylib qemu-system-arm

echo "Fixing dependencies for qemu-system-aarch64"

install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/Libs/libusb-1.0.0.dylib qemu-system-aarch64
install_name_tool -change /usr/local/opt/pixman/lib/libpixman-1.0.dylib @executable_path/Libs/libpixman-1.0.dylib qemu-system-aarch64
install_name_tool -change /usr/local/opt/glib/lib/libgthread-2.0.0.dylib @executable_path/Libs/libgthread-2.0.0.dylib qemu-system-aarch64
install_name_tool -change /usr/local/opt/glib/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib qemu-system-aarch64
install_name_tool -change /usr/local/opt/glib/lib/libgio-2.0.0.dylib @executable_path/Libs/libgio-2.0.0.dylib qemu-system-aarch64
install_name_tool -change /usr/local/opt/glib/lib/libgobject-2.0.0.dylib @executable_path/Libs/libgobject-2.0.0.dylib qemu-system-aarch64
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib qemu-system-aarch64
install_name_tool -change /usr/local/opt/glib/lib/libgmodule-2.0.0.dylib @executable_path/Libs/libgmodule-2.0.0.dylib qemu-system-aarch64

echo "Fixing dependencies for qemu-system-x86_64"

install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/Libs/libusb-1.0.0.dylib qemu-system-x86_64
install_name_tool -change /usr/local/opt/pixman/lib/libpixman-1.0.dylib @executable_path/Libs/libpixman-1.0.dylib qemu-system-x86_64
install_name_tool -change /usr/local/opt/glib/lib/libgthread-2.0.0.dylib @executable_path/Libs/libgthread-2.0.0.dylib qemu-system-x86_64
install_name_tool -change /usr/local/opt/glib/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib qemu-system-x86_64
install_name_tool -change /usr/local/opt/glib/lib/libgio-2.0.0.dylib @executable_path/Libs/libgio-2.0.0.dylib qemu-system-x86_64
install_name_tool -change /usr/local/opt/glib/lib/libgobject-2.0.0.dylib @executable_path/Libs/libgobject-2.0.0.dylib qemu-system-x86_64
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib qemu-system-x86_64
install_name_tool -change /usr/local/opt/glib/lib/libgmodule-2.0.0.dylib @executable_path/Libs/libgmodule-2.0.0.dylib qemu-system-x86_64

echo "Fixing dependencies for qemu-system-i386"

install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/Libs/libusb-1.0.0.dylib qemu-system-i386
install_name_tool -change /usr/local/opt/pixman/lib/libpixman-1.0.dylib @executable_path/Libs/libpixman-1.0.dylib qemu-system-i386
install_name_tool -change /usr/local/opt/glib/lib/libgthread-2.0.0.dylib @executable_path/Libs/libgthread-2.0.0.dylib qemu-system-i386
install_name_tool -change /usr/local/opt/glib/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib qemu-system-i386
install_name_tool -change /usr/local/opt/glib/lib/libgio-2.0.0.dylib @executable_path/Libs/libgio-2.0.0.dylib qemu-system-i386
install_name_tool -change /usr/local/opt/glib/lib/libgobject-2.0.0.dylib @executable_path/Libs/libgobject-2.0.0.dylib qemu-system-i386
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib qemu-system-i386
install_name_tool -change /usr/local/opt/glib/lib/libgmodule-2.0.0.dylib @executable_path/Libs/libgmodule-2.0.0.dylib qemu-system-i386

echo "Fixing dependencies for qemu-system-ppc"

install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/Libs/libusb-1.0.0.dylib qemu-system-ppc
install_name_tool -change /usr/local/opt/pixman/lib/libpixman-1.0.dylib @executable_path/Libs/libpixman-1.0.dylib qemu-system-ppc 
install_name_tool -change /usr/local/opt/glib/lib/libgthread-2.0.0.dylib @executable_path/Libs/libgthread-2.0.0.dylib qemu-system-ppc
install_name_tool -change /usr/local/opt/glib/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib qemu-system-ppc
install_name_tool -change /usr/local/opt/glib/lib/libgio-2.0.0.dylib @executable_path/Libs/libgio-2.0.0.dylib qemu-system-ppc
install_name_tool -change /usr/local/opt/glib/lib/libgobject-2.0.0.dylib @executable_path/Libs/libgobject-2.0.0.dylib qemu-system-ppc
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib qemu-system-ppc
install_name_tool -change /usr/local/opt/glib/lib/libgmodule-2.0.0.dylib @executable_path/Libs/libgmodule-2.0.0.dylib qemu-system-ppc

echo "Fixing dependencies for qemu-system-ppc64"

install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/Libs/libusb-1.0.0.dylib qemu-system-ppc64
install_name_tool -change /usr/local/opt/pixman/lib/libpixman-1.0.dylib @executable_path/Libs/libpixman-1.0.dylib qemu-system-ppc64
install_name_tool -change /usr/local/opt/glib/lib/libgthread-2.0.0.dylib @executable_path/Libs/libgthread-2.0.0.dylib qemu-system-ppc64
install_name_tool -change /usr/local/opt/glib/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib qemu-system-ppc64
install_name_tool -change /usr/local/opt/glib/lib/libgio-2.0.0.dylib @executable_path/Libs/libgio-2.0.0.dylib qemu-system-ppc64
install_name_tool -change /usr/local/opt/glib/lib/libgobject-2.0.0.dylib @executable_path/Libs/libgobject-2.0.0.dylib qemu-system-ppc64
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib qemu-system-ppc64
install_name_tool -change /usr/local/opt/glib/lib/libgmodule-2.0.0.dylib @executable_path/Libs/libgmodule-2.0.0.dylib qemu-system-ppc64

echo "Fixing dependencies for qemu-system-m68k"

install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/Libs/libusb-1.0.0.dylib qemu-system-m68k
install_name_tool -change /usr/local/opt/pixman/lib/libpixman-1.0.dylib @executable_path/Libs/libpixman-1.0.dylib qemu-system-m68k
install_name_tool -change /usr/local/opt/glib/lib/libgthread-2.0.0.dylib @executable_path/Libs/libgthread-2.0.0.dylib qemu-system-m68k
install_name_tool -change /usr/local/opt/glib/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib qemu-system-m68k
install_name_tool -change /usr/local/opt/glib/lib/libgio-2.0.0.dylib @executable_path/Libs/libgio-2.0.0.dylib qemu-system-m68k
install_name_tool -change /usr/local/opt/glib/lib/libgobject-2.0.0.dylib @executable_path/Libs/libgobject-2.0.0.dylib qemu-system-m68k
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib qemu-system-m68k
install_name_tool -change /usr/local/opt/glib/lib/libgmodule-2.0.0.dylib @executable_path/Libs/libgmodule-2.0.0.dylib qemu-system-m68k

echo "Fixing dependencies for qemu-img"

install_name_tool -change /usr/local/opt/glib/lib/libgthread-2.0.0.dylib @executable_path/Libs/libgthread-2.0.0.dylib qemu-img
install_name_tool -change /usr/local/opt/glib/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib qemu-img
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib qemu-img

cd Libs

echo "Fixing library dependencies"

#fix dependencies of libgthread-2.0.0.dylib 

install_name_tool -change /usr/local/Cellar/glib/2.68.3/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib libgthread-2.0.0.dylib
install_name_tool -change /usr/local/opt/pcre/lib/libpcre.1.dylib @executable_path/Libs/libpcre.1.dylib libgthread-2.0.0.dylib
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib libgthread-2.0.0.dylib

#fix dependencies for libglib-2.0.0.dylib
install_name_tool -change /usr/local/opt/pcre/lib/libpcre.1.dylib @executable_path/Libs/libpcre.1.dylib libglib-2.0.0.dylib
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib libglib-2.0.0.dylib

#libgio-2.0.0.dylib
install_name_tool -change /usr/local/Cellar/glib/2.68.3/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib libgio-2.0.0.dylib
install_name_tool -change /usr/local/Cellar/glib/2.68.3/lib/libgobject-2.0.0.dylib @executable_path/Libs/libgobject-2.0.0.dylib libgio-2.0.0.dylib
install_name_tool -change /usr/local/Cellar/glib/2.68.3/lib/libgmodule-2.0.0.dylib @executable_path/Libs/libgmodule-2.0.0.dylib libgio-2.0.0.dylib
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib libgio-2.0.0.dylib

#libgmodule-2.0.0.dylib
install_name_tool -change /usr/local/Cellar/glib/2.68.3/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib libgmodule-2.0.0.dylib

#libgobject-2.0.0.dylib
install_name_tool -change /usr/local/Cellar/glib/2.68.3/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib libgobject-2.0.0.dylib
install_name_tool -change /usr/local/opt/libffi/lib/libffi.7.dylib @executable_path/Libs/libffi.7.dylib libgobject-2.0.0.dylib

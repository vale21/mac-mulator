#!/bin/zsh

cd /Users/vale/Developer/Workspace\ Github/mac-mulator/MacMulator/Resources

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

install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/Libs/libusb-1.0.0.dylib qemu-system-ppc
install_name_tool -change /usr/local/opt/pixman/lib/libpixman-1.0.dylib @executable_path/Libs/libpixman-1.0.dylib qemu-system-ppc 
install_name_tool -change /usr/local/opt/glib/lib/libgthread-2.0.0.dylib @executable_path/Libs/libgthread-2.0.0.dylib qemu-system-ppc
install_name_tool -change /usr/local/opt/glib/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib qemu-system-ppc
install_name_tool -change /usr/local/opt/glib/lib/libgio-2.0.0.dylib @executable_path/Libs/libgio-2.0.0.dylib qemu-system-ppc
install_name_tool -change /usr/local/opt/glib/lib/libgobject-2.0.0.dylib @executable_path/Libs/libgobject-2.0.0.dylib qemu-system-ppc
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib qemu-system-ppc
install_name_tool -change /usr/local/opt/glib/lib/libgmodule-2.0.0.dylib @executable_path/Libs/libgmodule-2.0.0.dylib qemu-system-ppc

#fix dependencies of qemu-img

install_name_tool -change /usr/local/opt/glib/lib/libgthread-2.0.0.dylib @executable_path/Libs/libgthread-2.0.0.dylib qemu-img
install_name_tool -change /usr/local/opt/glib/lib/libglib-2.0.0.dylib @executable_path/Libs/libglib-2.0.0.dylib qemu-img
install_name_tool -change /usr/local/opt/gettext/lib/libintl.8.dylib @executable_path/Libs/libintl.8.dylib qemu-img

cd Libs

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

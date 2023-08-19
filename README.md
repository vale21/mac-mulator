# <img align="left" width="128" height="128" src="https://user-images.githubusercontent.com/47688632/131375200-1bb6224c-e6c9-4527-97a0-3814a2fccb16.png"> MacMulator
MacMulator is the computer emulator for your Mac! It engages the power of [Qemu](https://www.qemu.org) and [Apple Virtualization Framework](https://developer.apple.com/documentation/virtualization), together with a nice, easy to use UI, to let you create any kind of Virtual Machines in a few clicks. Whatever OS you need to run on your Mac, MacMulator is the tool for you!

MacMulator is a Universal app that works on Intel and Apple Silicon macs. It is able to recognize its host hardware and optimize the guest OS running in the operating system, to run it at almost native speed where possible. Whenever possible, it uses Apple Virtualization Framework to create a performant VM that enables 3D graphics and leverages macOS native features. For Qemu based VMs, It does not bundle Qemu executables, so it is very light, and lets you use the Qemu version you prefer. You have just to tell it where to find Qemu in your local machine, and you are ready to go.

![Screenshot 2021-08-30 at 16 27 13](https://user-images.githubusercontent.com/47688632/131355136-b78169e9-a401-4b45-b3db-2a57fd4ff748.png)

### Features

- Lets you create and run a VM in a few minutes, and with a few clicks
- Uses Apple Virtualization Framework to create native macOS VMs whenever possible (With Linux guests on macOS Ventura and higher, with macOS guests on macOS Monterey and higher, on Apple Silicon hosts)
- With Qemu, uses Apple Hypervisor to speed up your VM if the guest architecture is the same as the host one
- Emulates Intel, ARM, PowerPc and Motorola 68k and lets you install any kind of OS that works on these hardwares
- Lets you use the Qemu version you prefer, so that you can be very flexible. You can also custoimize the Qemu version for each VM
- If you are a pro user, lets you customize the Qemu command freely. MacMulator will use your version of the command in place of its own
- Vms are self contained and portable, very easy to share

### How to use

⚠️⚠️⚠️**WARNING! Beta software. Not all the features have been tested and there are still known bugs and limitations. Feel free to report bugs here if you find them**

1) Download the latest release of MacMulator and install it in your mac. The app is signed with Developer ID and notarized with Apple, so your Mac will accept it with no complain
2) Launch the application, open the Preferences panel and fill the path of your installation of Qemu. If you used [Homebrew](https://brew.sh) or [MacPorts](https://www.macports.org) to install Qemu you will probably find it already filled with the right path (Need help to install Qemu? Check [The official Qemu page](https://www.qemu.org/download/#macos) or [the E-macmulation forum](https://www.emaculation.com/forum/viewtopic.php?f=34&t=8848), that distributes good images of PowerPc Qemu)
4) Create your VM and launch it. You just need to specify a name and the OS you are going to install. MacMulator will do the rest
5) Enjoy your VM

![Screenshot 2021-08-30 at 16 30 30](https://user-images.githubusercontent.com/47688632/131355571-5dc96899-357b-4faa-838d-23e0be8a3904.png)

### Testing Status

Here is a summary of the testing done so far. If an OS is not in this table it means that it has not been tested at all

| Host Mac | Guest OS          | Guest Atchitecture | Status         | Notes                                                                                      |
| -------- | --------          | ------------------ | ------         | ------                                                                                     |
| Intel    | Mac OS X Cheetah   | PowerPc            | ✅ WORKING     | Tested with Qemu 6.1.0 via Homebrew and Qemu 5.2 from E-Macmulation                   |
| Intel    | Mac OS X Puma   | PowerPc            | ✅ WORKING     | Tested with Qemu 6.1.0 via Homebrew and Qemu 5.2 from E-Macmulation                   |
| Intel    | Mac OS X Jaguar   | PowerPc            | ✅ WORKING     | Tested with Qemu 6.0.0 via Homebrew and Qemu 5.2 from E-Macmulation                   |
| Intel    | Mac OS X Panther  | PowerPc            | ✅ WORKING     | Tested with Qemu 6.0.0 via Homebrew and Qemu 5.2 from E-Macmulation                   |
| Intel    | Mac OS X Tiger    | PowerPc            | ✅ WORKING     | Tested with Qemu 6.0.0 via Homebrew and Qemu 5.2 from E-Macmulation                   |
| Intel    | Mac OS X Leopard    | PowerPc            | ✅ WORKING     | Tested with Qemu 6.1.0 via Homebrew and Qemu 5.2 from E-Macmulation                   |
| Intel    | Mac OS X Snow Leopard | x86_64             | ⚠️ WORKING WITH ISSUES | Works in Beta 11 or later with no audio and no HVF |
| Intel    | Mac OS X Lion | x86_64             | ⚠️ WORKING WITH ISSUES |  Works in Beta 12 or later with no audio and no HVF |
| Intel    | OS X Mountain Lion | x86_64             | ⚠️ WORKING WITH ISSUES | Works in Beta 13 or later with no audio and no HVF |
| Apple Silicon | OS X Mountain Lion | x86_64             | ⚠️ WORKING WITH ISSUES | Works in Beta 13 or later with no audio |
| Intel    | OS X Mavericks | x86_64             | ⚠️ WORKING WITH ISSUES | Works in Beta 14 or later with no audio and no HVF |
| Intel    | OS X Yosemite | x86_64             | 🚫 NOT WORKING | Installs on Beta 13 or later, but with no networking and no HVF. It is too slow to be usable, even on powerful hardware. |
| Intel    | OS X El Capitan | x86_64             | ⚠️ WORKING WITH ISSUES | Works in Beta 13 or later with no audio |
| Intel    | macOS Sierra | x86_64             | 🚫 NOT WORKING | Did not have a successful boot. |
| Intel    | macOS High Sierra | x86_64             | ⚠️ WORKING WITH ISSUES | Works in Beta 11 or later with no audio |
| Intel    | macOS Catalina    | x86_64             | ⚠️ WORKING WITH ISSUES | Works in Beta 11 or later with no audio |
| Intel    | macOS Big Sur     | x86_64             | ⚠️ WORKING WITH ISSUES | Works in Beta 11 or later with no audio |
| Intel    | macOS Monterey    | x86_64             | 🚫 NOT WORKING  | 12.2 Does not boot. 12.0 and 12.1 do, if installed via an update to Big Sur |
| Apple Silicon | macOS Monterey    | aarch64             | ✅ WORKING  | Works in Beta 14 or later using Apple Virtualization Framework |
| Apple Silicon | macOS Ventura    | aarch64             | ✅ WORKING  | Works in Beta 14 or later using Apple Virtualization Framework |
| Intel    | Windows XP        | i386               | ✅ WORKING     | Works, but no HVF due to different architecture (32/64 bit). No 3D acceleration  |             
| Intel    | Windows Vista        | x86_64             | ✅ WORKING     | Works in Beta 14 or later with HVF support. No 3D acceleration                                                 |
| Intel    | Windows 7        | x86_64             | ✅ WORKING     | Works in Beta 14 or later with HVF support. No 3D acceleration                                                 |
| Intel    | Windows 8        | x86_64             | ✅ WORKING     | Works in Beta 14 or later with HVF support. No 3D acceleration                                                 |
| Intel    | Windows 8.1        | x86_64             | ✅ WORKING     | Works in Beta 14 or later with HVF support. No 3D acceleration                                                 |
| Intel    | Windows 10        | x86_64             | ✅ WORKING     | Works with HVF support. No 3D acceleration                                                 |
| Apple M1 | Windows 10 ARM    | aarch64            | ⚠️ WORKING WITH ISSUES | Works in Beta 15 or later with no networking, only if booted from a VHDX image                                                         |
| Intel    | Ubuntu 21.04      | x86_64             | ⚠️ WORKING WITH ISSUES     | Works with HVF support. No 3D acceleration                                                 |
| Intel    | Ubuntu 22.10      | x86_64             | ✅ WORKING     | Works in Beta 16 or later using Apple Virtualization Framework                                                 |
| Intel    | Ubuntu 20.04 ARM  | aarch64            | ⚠️ WORKING WITH ISSUES     | Works, but no HVF due to different architecture. No 3D acceleration                   | 
| Apple M1 | Ubuntu 20.04 ARM  | aarch64            | ⚠️ WORKING WITH ISSUES     | Works with HVF support if using Qemu 6.2 or later. No 3D acceleration |  
| Apple M1 | Ubuntu 22.10 ARM  | aarch64            | ✅ WORKING     | Works in Beta 16 or later using Apple Virtualization Framework |  




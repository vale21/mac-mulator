//
// swtpm_launcher.c
//
// The UTM sysroot ships swtpm as a library (swtpm.0.framework) that exposes a
// swtpm_main() entry point, which is how UTM itself runs it. This small
// executable, compiled by scripts/embed_sysroot_frameworks.sh into
// Contents/MacOS/swtpm of the App Store flavor, turns it back into the swtpm
// command that MacMulator runs for VMs with an emulated TPM:
//
//     swtpm socket --tpmstate dir=... --ctrl type=unixio,path=... --tpm2
//
#include <string.h>

// From UTM's build of swtpm: runs "swtpm <iface>" with the given options.
extern int swtpm_main(int argc, const char *argv[], const char *prgname, const char *iface);

int main(int argc, const char *argv[]) {
    const char *iface = "socket";
    if (argc >= 2 && (strcmp(argv[1], "socket") == 0 || strcmp(argv[1], "chardev") == 0)) {
        // The library takes the interface as a parameter: drop it from the arguments,
        // keeping argv[0] as the program name.
        iface = argv[1];
        argv[1] = argv[0];
        argv++;
        argc--;
    }
    return swtpm_main(argc, argv, "swtpm", iface);
}

# Windows Apple Magic Keyboard Fix v1

Free Windows x64 HID lower-filter driver for the **Apple Magic Keyboard A1644 / PID 0267**.

Magic Keyboard Fix remaps the Apple-specific modifier/function behavior at the Windows HID driver level. No background app, tray utility, or subscription is required after installation.

## Verified

- Windows 10 x64
- Apple Magic Keyboard A1644 / PID 0267
- **A Bluetooth connection**
- Driver builds, installs, loads, and remaps successfully on real hardware

## Not yet verified

- **Lightning-to-USB connection**. Support for the A1644 / PID 0267 USB path is included in the driver, but it has not yet been tested on real hardware.

## Fixed mapping (makes the Magic Keyboard into a standard Windows keyboard in terms of keyboard layout)

| Physical key | Windows result |
| --- | --- |
| Fn | Left Ctrl |
| Control | Ctrl |
| Option | Windows key |
| Command | Alt |
| Eject | Forward Delete |

The left side therefore behaves as:

`Ctrl | Ctrl | Win | Alt | Space | Alt | Ctrl`

## Download

**[Download Magic Keyboard Fix v1](https://github.com/mudalepsishake/magic-keyboard-fix/releases/download/v1/Magic-Keyboard-Fix-v1-test-signed.zip)**

No Visual Studio or WDK is required to use the prebuilt driver. See the installation instructions below.

## Installing the prebuilt v1 release

The downloadable v1 driver is **test-signed**, not Microsoft production-signed. Windows must therefore be in **TESTSIGNING** mode for the driver to load.

1. Download **`Magic-Keyboard-Fix-v1-test-signed.zip`** from the link above or from the GitHub Releases page.
2. Extract the entire ZIP to a normal folder. Do not run the files from inside the ZIP.
3. Run **`INSTALL TEST CERTIFICATE FIRST.cmd`** as Administrator and approve the UAC prompt if prompted.
4. Run **`3 ENABLE TESTSIGNING.cmd`** as Administrator and approve the UAC prompt if prompted.
5. **Reboot Windows.**
6. Run **`4 INSTALL DRIVER.cmd`** as Administrator and approve the UAC prompt if prompted.
7. Connect the Magic Keyboard via Bluetooth or Lightning USB if you have not already.
8. Test the mappings listed above.
9. (Optional) Reboot Windows again or disconnect/reconnect the Magic Keyboard if needed.

You do **not** need Visual Studio, the Windows SDK, or the WDK to use the prebuilt release. Those are only required if you want to build the driver from source.

### Secure Boot

If `3 ENABLE TESTSIGNING.cmd` reports that TESTSIGNING cannot be changed because the value is protected by Secure Boot policy, disable Secure Boot in UEFI/BIOS, run the script again, and reboot.

## Uninstall

1. Run **`5 UNINSTALL DRIVER.cmd`** as Administrator and approve the UAC prompt if prompted.
2. Reboot Windows.
3. If you no longer need Windows TESTSIGNING mode for anything else, run **`6 DISABLE TESTSIGNING.cmd`** as Administrator and approve the UAC prompt if prompted.
4. Reboot Windows again.

The public test certificate is intentionally not removed automatically by the tested-working uninstall script. It can be removed manually later from the Local Computer certificate stores if desired.

## Building from source

Building is optional. Users of the prebuilt Release ZIP can skip this section.

The source tree contains the same build path used for the tested-working v1 driver:

1. Install Visual Studio / Build Tools with the C++ driver-development components.
2. Run **`0 INSTALL WDK PREREQUISITES.cmd`** if the matching Windows SDK/WDK prerequisites are missing.
3. Run **`1 BUILD RELEASE.cmd`**.
4. Run **`2 MAKE TEST PACKAGE.cmd`** to create the local test-signed package.

The successful Release build produces:

`driver\build\Release\MagicKeyFix.sys`

The package-building step creates the matched INF/SYS/CAT package and test certificate used for installation.

## Source layout

- `driver/Driver.c` - Windows HID lower-filter driver implementation
- `driver/Driver.h` - driver declarations
- `driver/A1644Core.S` - A1644 report transformation in x86-64 assembly
- `driver/MagicKeyFix.inf` - driver installation information
- `driver/MagicKeyFix.vcxproj` - Visual Studio driver project
- `MagicKeyFix.sln` - Visual Studio solution
- `tools/` - build, package, install, uninstall, and TESTSIGNING PowerShell scripts
- `ui/` - MagicKeyFix control utility
- `VALIDATION.txt` - validation/testing notes for the A1644 transform
- `THIRD_PARTY_NOTICES.txt` - attribution and license notice for third-party reference material

## How it works

Magic Keyboard Fix is a Windows x64 HID lower-filter driver. It intercepts the A1644 input report in the Windows HID stack, transforms the Apple-specific modifier/Fn/Eject state, and passes the resulting report upward normally.

The A1644 transform itself is implemented in hand-written x86-64 assembly in `driver/A1644Core.S`.

## Validation

The A1644 transform was tested across **4,096 modifier/Fn/Eject/key-slot combinations**, plus the short-report guard. See `VALIDATION.txt` for the exact validation notes.

## Third-party notice

The A1644 bus-interception approach and report layout were cross-checked against George Samartzidis's MIT-licensed **WinAppleKey** project.

See **`THIRD_PARTY_NOTICES.txt`** for the original project reference, copyright notice, and MIT license text.

## Reporting issues

When reporting a problem, please include:

- Windows version
- Exact Apple keyboard model
- Bluetooth or Lightning-to-USB connection
- Complete output from whichever install/build script failed

## License

Magic Keyboard Fix is released under the MIT License. See `LICENSE`.

## Disclaimer

This project is independent (indie, N.D. [sic], in D [sic], in Dee [sic], indy [sic], enndee [sic]) and is not affiliated with or endorsed by Apple, Microsoft or any other unrelated entities that wish to vacuum money out of your pockets.

---

**This project is completely hammered!**  
by `mudalepsishake`

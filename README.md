# MagicKeyFix v1

First public release of MagicKeyFix, a free Windows x64 HID lower-filter driver for the Apple Magic Keyboard A1644 / PID 0267.

### Verified

- Windows 10 x64
- Apple Magic Keyboard A1644
- Lightning-to-USB connection
- Driver builds, installs, loads, and remaps the keyboard successfully on real hardware

### Fixed mapping

- Fn -> Left Ctrl
- Control -> Ctrl
- Option -> Windows key
- Command -> Alt
- Eject -> Forward Delete

### Notes

This release is test-signed, not Microsoft production-signed. Windows TESTSIGNING mode is required. Depending on the PC, Secure Boot may need to be disabled before TESTSIGNING can be enabled.

Bluetooth support for the A1644/PID 0267 path is included in the driver but has not yet been verified on real hardware.

### Release assets

Download `MagicKeyFix_v1.0.0_test-signed.zip` if you want the prebuilt driver package. Source code is also available directly from the repository.

Please report the Windows version, connection type (Lightning USB or Bluetooth), and exact keyboard model when filing an issue.

## v18.4

### Added
- Option to ignore diagonal inputs from the D-Pad
- Option to use the background palette 0 color (prevents screen transition flash)
- Option to set low battery icon display behavior

### Changed
- Tuned battery thresholds for 1.2V NiMH AA's

### Fixed
- Reduce backlight flashing when power source is nearly depleted
- Support for Kirby Tilt-n-Tumble
- Improved Chromatic firmware version detection
- Support streaming to Linux platforms

## v18.0

### Changed
- Improved button debouncing.

### Fixed
- Fully mute game audio when speaker wheel is turned to minimum.
- Silent mode mutes all device audio output.
- Suppress invalid DPAD inputs to correct character sprite glitch.
- Color decoding bug corrected (greyscale check).

## v17.0

### Note
The MCU must be updated to v0.12.X or newer as the underlying communication protocol changed.

### Changed
- Enable backlight switch on independent from MCU communication.
- Supports updated UART protocol.

## v16.0

### Note
The version of the IDE was switched to Gowin IDE v1.9.9.03. This resolves a synthensis bug which resulted in a palette flickering issue. Do not build with Gowin IDE v1.9.9.02 or older going forward.

### Added
- Reset the FPGA core when a cartridge is removed.
- Add hotkey for reset (Menu+A+B+Start+Select).
- Add hotkeys for brightness (Menu+Left/Right).

### Changed
- Only show icon overlays when the OSD is off.
- USB CDC descriptors for Linux & macOS.

### Fixed
- Improved AA/LiPo detection logic to resolve critical battery false positives.
- Fixes palette flickering issue seen on some games like Tetris.

## v13.1
This is the first production release.

## v13.0 and older
A preliminary engineering release.

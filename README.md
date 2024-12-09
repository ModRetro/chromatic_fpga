# Chromatic FPGA
This repository houses the ModRetro Chromatic's FPGA design files.

For more information about the ModRetro Chromatic, please see visit [ModRetro.com](https://modretro.com/).

## Setup

### Repository

This project builds upon the open source work provided by the Game Boy `MiSTer` project. When checking out this repository, make sure to run the following command as this repository submodules the Game Boy `MiSTer` project.

```bash
git submodule update --init --remote --recursive
```

### Gowin Development Environment

The Gowin FPGA Designer must be installed (Gowin IDE v1.9.9.03 or newer must be used).

You will also need to apply for a local license with Gowin through their website:
https://www.gowinsemi.com/en/support/license

The license expires after one year and will require reactivation.

You will receive an email within a few minutes with a `.lic` file attached. Run the Gowin IDE and install the license when it prompts you. You'll need to close and re-open the GOWIN IDE if everything was successful.

## Building
Once in the IDE, load `evt1_x2.gprj` project and click on the green recycle-like button icon to run synthesis and PnR. This will take about 5-10 minutes to complete.

## Flashing
Flashing can be performed using the official [Gowin Programmer](https://www.gowinsemi.com/en/) software or the [`openFPGALoader`](https://github.com/trabucayre/openFPGALoader) utility through the Chromatic's USB interface.

Note:
1. The Chromatic must be powered on for either tool to detect the FPGA. This means the power switch is in the **ON** position.
2. If using `openFPGALoader`, the tool must be compiled with support for the Gowin GWU2X cable.

### Example Using `openFPGALoader`
**Detect the Chromatic FPGA While Powered On**
```bash
openFPGALoader --detect --cable gwu2x
```

You will see an output similar to:
```
empty
User requested: 6000000 real frequency is 6000000
index 0:
        idcode 0x1281b
        manufacturer Gowin
        family GW5A
        model  GW5A-25
        irlength 8
```

**Flashing the Chromatic**

```bash
openFPGALoader --write-flash --cable gwu2x --reset <file>
```

Here, `<file>` refers to the generated bitstream file. This file can be found at esp32t/impl/pnr/evt1_x2.fs.

## Issues
Please submit all issues and bug reports through our [Contact Form](https://modretro.com/pages/contact).

## Attributions
- [GOWIN Semiconductor](https://www.gowinsemi.com/en/)
- [MiSTer](https://github.com/MiSTer-devel/Gameboy_MiSTer)

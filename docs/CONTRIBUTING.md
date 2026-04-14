# Contributing to MMI3G-Toolkit

## Adding a New Module

1. Create a directory under `modules/` with your module name
2. Add a `module.json` with this structure:

```json
{
    "name": "my-module",
    "version": "1.0.0",
    "description": "What this module does",
    "author": "your-name",
    "status": "ready",
    "compatible": ["MMI3G", "MMI3G+", "RNS-850"],
    "script_dir": "/scripts/MyModule",
    "screens": ["list of .esd files"],
    "scripts": ["list of .sh files"]
}
```

3. Add GEM screen definitions in `engdefs/` (`.esd` files)
4. Add helper scripts in `scripts/` (`.sh` files)
5. Test on your vehicle before submitting

## Module Guidelines

- Set `status` to `"planned"` until tested on real hardware
- All scripts must handle missing SD card gracefully
- Use `/bin/ksh` shebang (QNX default shell)
- Log output to `${SDPATH}/var/` on the SD card
- Scripts triggered from GEM buttons should be fast (<5 sec)
- Include uninstall instructions in module.json

## ESD Screen Format Reference

```
# Parent screen (creates submenu in GEM root)
screen MyScreen ParentScreen

# Integer value with polling interval (ms)
keyValue value int per 3 0x00000023 label "My Value:"
poll 500

# String value (static, no polling)
keyValue value String per 1 0x0000100d label "Version:"

# Script button (runs shell script, output in GEM console)
script value sys 1 0x0100 "/scripts/MyModule/myscript.sh" label ">> Run Script <<"

# Slider control (min to max)
slider value per 3 0x00140007 0 31 label "Setting:"
```

### Personality Sources (per X)
- `per 1` = MMI system data
- `per 3` = Vehicle / CAN bus data
- `per 7` = GPS / Navigation data

## Testing

Always test on a real MMI3G unit before marking a module as `ready`.
The QNX 6.5.0 SP1 VM can verify script syntax but cannot simulate
the GEM environment or CAN bus data.

## Credits

When building on community research, please credit:
- DrGER2 for MMI3G+ research and tools
- megusta1337 for copie_scr.sh decoding
- The Audizine, A5OC, VWVortex, and ClubTouareg communities

# P0824 GEMMI Donor Binaries

The large binaries (gemmi_final, libembeddedearth.so, models, fonts) are hosted
as a GitHub Release asset to keep the repository lean.

**Download:** [gemmi_p0824_eu_vw.zip](https://github.com/dspl1236/MMI3G-Toolkit/releases/download/v1.0-gemmi-p0824/gemmi_p0824_eu_vw.zip) (9.8MB)

Extract into `modules/google-earth-p0824-deploy/gemmi/` before building an SD card
with this module. The deploy script expects these files:

- `gemmi_final` (1.9MB)
- `libembeddedearth.so` (20.5MB)
- `libmessaging.so` (826KB)
- `mapStylesWrite` (507KB)
- `models/` (icons, cursors, traffic overlays)
- `res/` (VWThesis fonts)

**Source:** HN+_EU_VW_P0824 firmware (ECE VW Touareg)
**Version:** GEMMI 5.2.0.6394 (same engine as NAR Audi K0942)

## Also Available

NAR Audi K0942 binaries are available as individual release assets on the
[same release page](https://github.com/dspl1236/MMI3G-Toolkit/releases/tag/v1.0-gemmi).

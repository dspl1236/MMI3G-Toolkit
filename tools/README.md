# Internal development tools

These scripts are used by maintainers during audits. They are not
user-facing and not shipped in the built SD card.

## retrofit.py

Applies the platform.sh source block + `$(mmi_logstamp)` substitution to
module scripts. Used during the DrGER2-review audit pass (see commit
history). Idempotent — running it against an already-retrofitted script
is a no-op.

Usage:
```
python3 tools/retrofit.py
```

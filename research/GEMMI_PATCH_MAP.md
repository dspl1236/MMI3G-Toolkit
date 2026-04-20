# GEMMI Google Earth Patch Map
# Source: gemmi_final + libembeddedearth.so from HN+R_US_AU_K0942_3
# Date: 2026-04-20

## CRITICAL PATCH POINTS (libembeddedearth.so, 20.5MB)

### Auth Server (DEAD — returns 404)
```
0x104a434: "geoauth.google.com"     (18 chars)
           → Replace with proxy or null out to skip auth
```

### Tile Server (BLOCKED — returns 403)
```
0x104a5bc: "kh.google.com"          (13 chars)
0x1043dcc: "http://kh.google.com/"  (20 chars)
0x1043dd3: "kh.google.com/"         (14 chars)
           → Replace with proxy hostname
```

### Street View (may still work)
```
0x1069770: "http://cbk0.google.com/cbk"
0x1069800: "http://cbk0.google.com"
```

### Maps/Geocoding
```
0x104a4c8: "http://maps.google.com"
0x104a54c: "http://maps.google.com/maps/api/earth/GeocodeService.Search"
```

## KEY INSIGHT: hausofdub.com = 13 chars = kh.google.com!

Perfect byte-for-byte replacement. No padding needed.

## CONFIGURABLE SETTINGS (drivers.ini)

Already has: `Connection/enableSeamlessLogin = true`

Possible additions from libembeddedearth.so symbols:
- `loginServer` — override auth server address?
- `maxLoginAttempts` — set to 0 to skip retries?
- `loginTimeout` — reduce to fail fast?
- `loginBeforeGuiCreation` — change login timing?

## PROPOSED PATCH STRATEGY

### Option A: Binary patch + Proxy (most reliable)
1. In libembeddedearth.so:
   - 0x104a434: "geoauth.google.com" → "hausofdub.com\x00\x00\x00\x00\x00"
   - 0x104a5bc: "kh.google.com"      → "hausofdub.com"
   - 0x1043dd3: "kh.google.com/"     → "hausofdub.com/"
2. PHP proxy on hausofdub.com translates URL format
3. drivers.ini unchanged

### Option B: Config-only (if loginServer is configurable)
1. drivers.ini: loginServer = hausofdub.com
2. drivers.ini: Connection/enableSeamlessLogin = false
3. DNS redirect kh.google.com → hausofdub.com (via LTE router)
4. No binary patching!
   BUT: SSL cert mismatch may break HTTPS

### Option C: Auth bypass only + DNS
1. Patch auth check to always succeed
2. DNS redirect kh.google.com via LTE router DHCP/DNS
3. Proxy only handles URL format translation
4. Still need binary patch for auth

## PROXY (hausofdub.com)

```
Car requests:  GET /kh/v=943&x=5&y=10&z=8
Proxy fetches: GET mt0.google.com/vt?lyrs=s&x=5&y=10&z=8
Returns:       JPEG satellite tile (256x256)
```

~20 lines of PHP. Google tile servers (mt0/mt1) confirmed
still serving tiles as of 2026-04-20 (HTTP 200).

## NEXT STEPS

1. Test if drivers.ini loginServer override works
2. If not, do binary patch (Option A)
3. Write PHP proxy for hausofdub.com
4. Test with LTE data connection

#!/usr/bin/env python3
"""
gemmi_tile_proxy.py — Google Earth tile proxy for MMI3G+ GEMMI

Runs on your PC (e.g. 192.168.0.91). The MMI's /etc/hosts points
kh.google.com at this proxy. GEMMI sends tile requests using the
old Google Earth Enterprise protocol; this proxy translates them
to Google's public tile API which still serves imagery.

Setup:
  1. On MMI (telnet root shell):
     echo "192.168.0.91 kh.google.com" >> /etc/hosts
     slay gemmi_final

  2. On your PC:
     python gemmi_tile_proxy.py

  3. GEMMI auto-restarts and requests tiles through this proxy.

Protocol translation:
  GEMMI requests:  GET /flatfile?db=earth&t=tqsrts&q=250&channel=0&version=943
  Quadkey 't...' is a Google-style tile address (t=root, then q/r/s/t quadrants)
  This proxy converts the quadkey to x/y/z coordinates and fetches from:
    https://mt0.google.com/vt?lyrs=s&x={x}&y={y}&z={z}

  GEMMI also requests:
    /dbRoot.v5        -> forwarded to real kh.google.com (still works, 200)
    /geauth           -> returns fake success (endpoint is dead, 404)
    /flatfile?...     -> tile proxy (the main job)

Part of MMI3G-Toolkit: github.com/dspl1236/MMI3G-Toolkit
"""

import http.server
import urllib.request
import urllib.error
import ssl
import sys
import re

LISTEN_PORT = 80
REAL_KH_HOST = "kh.google.com"
TILE_HOST = "mt0.google.com"

# Google quadkey: t=root, then q=0,r=1,s=2,t=3 for each zoom level
QUADKEY_MAP = {'q': 0, 'r': 1, 's': 2, 't': 3}

def quadkey_to_xyz(quadkey):
    """Convert Google Earth quadkey (tqsrts...) to x, y, z tile coords."""
    # Strip leading 't' (root)
    if quadkey.startswith('t'):
        quadkey = quadkey[1:]
    z = len(quadkey)
    x = 0
    y = 0
    for i, ch in enumerate(quadkey):
        bit = z - 1 - i
        val = QUADKEY_MAP.get(ch, 0)
        x |= (val & 1) << bit
        y |= ((val >> 1) & 1) << bit
    return x, y, z


class GEMMIProxyHandler(http.server.BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        print(f"[GEMMI] {args[0]}")

    def do_GET(self):
        path = self.path

        # --- /geauth — fake auth success ---
        if '/geauth' in path:
            print(f"[AUTH]  Faking auth success for: {path}")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"authorized")
            return

        # --- /flatfile — tile proxy (the main job) ---
        if '/flatfile' in path:
            # Parse quadkey from 't' parameter
            m = re.search(r'[&?]t=([qrst]+)', path)
            if m:
                quadkey = m.group(1)
                x, y, z = quadkey_to_xyz(quadkey)
                tile_url = f"https://{TILE_HOST}/vt?lyrs=s&x={x}&y={y}&z={z}"
                print(f"[TILE]  {quadkey} -> z={z} x={x} y={y}")
                try:
                    ctx = ssl.create_default_context()
                    req = urllib.request.Request(tile_url, headers={
                        "User-Agent": "GoogleEarth/5.2.0.6394"
                    })
                    resp = urllib.request.urlopen(req, context=ctx, timeout=10)
                    data = resp.read()
                    self.send_response(200)
                    self.send_header("Content-Type", "image/jpeg")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    print(f"[TILE]  Served {len(data)} bytes")
                    return
                except Exception as e:
                    print(f"[TILE]  FAILED: {e}")
                    self.send_response(502)
                    self.end_headers()
                    return
            else:
                print(f"[TILE]  No quadkey in: {path}")
                self.send_response(404)
                self.end_headers()
                return

        # --- /dbRoot.v5 and everything else — forward to real Google ---
        try:
            real_url = f"https://{REAL_KH_HOST}{path}"
            print(f"[FWD]  -> {real_url}")
            ctx = ssl.create_default_context()
            req = urllib.request.Request(real_url, headers={
                "User-Agent": "GoogleEarth/5.2.0.6394",
                "Host": REAL_KH_HOST,
            })
            resp = urllib.request.urlopen(req, context=ctx, timeout=10)
            data = resp.read()
            self.send_response(resp.status)
            self.send_header("Content-Type", resp.headers.get("Content-Type", "application/octet-stream"))
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except urllib.error.HTTPError as e:
            print(f"[FWD]  HTTP {e.code}: {real_url}")
            self.send_response(e.code)
            self.end_headers()
        except Exception as e:
            print(f"[FWD]  FAILED: {e}")
            self.send_response(502)
            self.end_headers()


def main():
    port = LISTEN_PORT
    if len(sys.argv) > 1:
        port = int(sys.argv[1])

    print(f"=" * 50)
    print(f"  GEMMI Tile Proxy")
    print(f"  Listening on 0.0.0.0:{port}")
    print(f"  Tile source: {TILE_HOST}")
    print(f"=" * 50)
    print()
    print("  On the MMI root shell, run:")
    print(f'  echo "192.168.0.91 kh.google.com" >> /etc/hosts')
    print("  slay gemmi_final")
    print()
    print("  Waiting for GEMMI connections...")
    print()

    server = http.server.HTTPServer(("0.0.0.0", port), GEMMIProxyHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nProxy stopped.")
        server.server_close()


if __name__ == "__main__":
    main()

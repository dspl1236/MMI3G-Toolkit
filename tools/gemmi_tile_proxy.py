#!/usr/bin/env python3
"""GEMMI Tile Proxy — Cookie Auth Mode
Based on binary analysis of libembeddedearth.so:
  geFreeLoginServer = kh.google.com + /geauth
  Auth uses Set-Cookie (Netscape HTTP Cookie File format)
"""
import http.server, os, urllib.request, urllib.error, ssl, sys, re, time

LISTEN_PORT = 80
REAL_KH_HOST = "kh.google.com"
TILE_HOST = "mt0.google.com"
DBROOT_CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dbRoot.v5.cached")
QUADKEY_MAP = {'q': 0, 'r': 1, 's': 2, 't': 3}

def quadkey_to_xyz(qk):
    if qk.startswith('t'): qk = qk[1:]
    z = len(qk); x = y = 0
    for i, ch in enumerate(qk):
        bit = z - 1 - i; val = QUADKEY_MAP.get(ch, 0)
        x |= (val & 1) << bit; y |= ((val >> 1) & 1) << bit
    return x, y, z

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): print(f"[GEMMI] {args[0]}")

    def do_POST(self):
        path = self.path
        if '/geauth' in path:
            cl = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(cl) if cl > 0 else b""
            print(f"[AUTH]  POST /geauth ({cl} bytes)")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Set-Cookie", "SID=gemmi_session_valid; Domain=.google.com; Path=/; Expires=Thu, 01 Jan 2099 00:00:00 GMT")
            self.send_header("Set-Cookie", "HSID=AkGEhV3xR; Domain=.google.com; Path=/; HttpOnly")
            self.end_headers()
            self.wfile.write(b"1")
            print(f"[AUTH]  Returned 200 + Set-Cookie")
            return
        cl = int(self.headers.get('Content-Length', 0))
        if cl > 0: self.rfile.read(cl)
        self.send_response(200); self.end_headers()

    def do_GET(self):
        path = self.path
        if '/geauth' in path:
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Set-Cookie", "SID=gemmi_session_valid; Domain=.google.com; Path=/")
            self.end_headers()
            self.wfile.write(b"1")
            return
        if '/flatfile' in path:
            m = re.search(r'[&?]t=([qrst]+)', path)
            if m:
                qk = m.group(1); x, y, z = quadkey_to_xyz(qk)
                url = f"https://{TILE_HOST}/vt?lyrs=s&x={x}&y={y}&z={z}"
                print(f"[TILE]  {qk} -> z={z} x={x} y={y}")
                try:
                    ctx = ssl.create_default_context()
                    req = urllib.request.Request(url, headers={"User-Agent": "GoogleEarth/5.2.0.6394"})
                    resp = urllib.request.urlopen(req, context=ctx, timeout=10)
                    data = resp.read()
                    self.send_response(200)
                    self.send_header("Content-Type", "image/jpeg")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    print(f"[TILE]  Served {len(data)} bytes")
                except Exception as e:
                    print(f"[TILE]  FAILED: {e}")
                    self.send_response(502); self.end_headers()
                return
            self.send_response(404); self.end_headers(); return
        if '/dbRoot' in path:
            if os.path.exists(DBROOT_CACHE):
                with open(DBROOT_CACHE, 'rb') as f: data = f.read()
                print(f"[ROOT] Serving cached dbRoot.v5 ({len(data)} bytes)")
                self.send_response(200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            else:
                self.send_response(404); self.end_headers()
            return
        try:
            url = f"https://{REAL_KH_HOST}{path}"
            print(f"[FWD]  -> {url}")
            ctx = ssl.create_default_context()
            req = urllib.request.Request(url, headers={"User-Agent": "GoogleEarth/5.2.0.6394", "Host": REAL_KH_HOST})
            resp = urllib.request.urlopen(req, context=ctx, timeout=10)
            data = resp.read()
            self.send_response(resp.status)
            self.send_header("Content-Type", resp.headers.get("Content-Type", "application/octet-stream"))
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except urllib.error.HTTPError as e:
            self.send_response(e.code); self.end_headers()
        except Exception as e:
            self.send_response(502); self.end_headers()

def main():
    port = LISTEN_PORT
    if len(sys.argv) > 1: port = int(sys.argv[1])
    print(f"{'='*50}")
    print(f"  GEMMI Tile Proxy — Cookie Auth")
    print(f"  Listening on 0.0.0.0:{port}")
    print(f"{'='*50}\n  Waiting for GEMMI connections...\n")
    server = http.server.HTTPServer(("0.0.0.0", port), Handler)
    try: server.serve_forever()
    except KeyboardInterrupt: print("\nStopped."); server.server_close()

if __name__ == "__main__": main()

#!/usr/bin/env python3
"""GEMMI Proxy v18 — Fully self-contained, NO xgx dependency!
- dbRoot: served from local file (dbRoot_xgx.bin)
- Auth: served from cached responses (auth_resp1.bin, auth_resp2.bin)
- Quadtree + Tiles: kh.google.com (REAL Google Earth)
"""
import http.server, os, urllib.request, urllib.error, ssl, sys, re, hashlib

LISTEN_PORT = 80
GOOGLE = "https://kh.google.com"
UA = "GoogleEarth/7.3.6.9796(Windows;Microsoft Windows (6.2.9200.0);en;kml:2.2;client:Free;type:default)"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR = os.path.join(BASE_DIR, "tile_cache")
os.makedirs(CACHE_DIR, exist_ok=True)
CTX = ssl.create_default_context()

# Load local files
with open(os.path.join(BASE_DIR, "dbRoot_xgx.bin"), "rb") as f:
    DBROOT = f.read()
with open(os.path.join(BASE_DIR, "auth_resp1.bin"), "rb") as f:
    AUTH1 = f.read()
with open(os.path.join(BASE_DIR, "auth_resp2.bin"), "rb") as f:
    AUTH2 = f.read()
print("  dbRoot: %d bytes (local)" % len(DBROOT))
print("  Auth1: %d bytes, Auth2: %d bytes (local)" % (len(AUTH1), len(AUTH2)))

def cache_get(key):
    p = os.path.join(CACHE_DIR, key)
    if os.path.exists(p):
        with open(p, "rb") as f: return f.read()
    return None

def cache_put(key, data):
    with open(os.path.join(CACHE_DIR, key), "wb") as f: f.write(data)

def fetch_google(path):
    ck = hashlib.md5(path.encode()).hexdigest()
    cached = cache_get("g_" + ck)
    if cached: return cached
    try:
        req = urllib.request.Request(GOOGLE + path, headers={"User-Agent": UA})
        data = urllib.request.urlopen(req, context=CTX, timeout=15).read()
        if len(data) > 2: cache_put("g_" + ck, data)
        return data
    except Exception as e:
        print("[ERR]   %s" % e); return None

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): pass

    def do_POST(self):
        cl = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(cl) if cl > 0 else b""
        if '/geauth' in self.path:
            data = AUTH2 if cl >= 49 else AUTH1
            print("[AUTH]  (%db) -> %db LOCAL" % (cl, len(data)))
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        self.send_response(200); self.end_headers()

    def do_GET(self):
        path = self.path
        query = path.split("?", 1)[1] if "?" in path else ""
        if '/dbRoot' in path:
            print("[ROOT]  dbRoot (%db) LOCAL" % len(DBROOT))
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(len(DBROOT)))
            self.end_headers()
            self.wfile.write(DBROOT)
            return
        if '/flatfile' in path:
            data = fetch_google(path)
            if data and len(data) > 2:
                tag = "QT  " if 'q2' in query else "TILE" if re.match(r'f\d+', query) else "FLAT"
                print("[%s]  %s -> %db" % (tag, query[:50], len(data)))
                self.send_response(200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            else:
                print("[404]  %s" % query[:50])
                self.send_response(404); self.end_headers()
            return
        self.send_response(200); self.send_header("Content-Length", "0"); self.end_headers()

def main():
    port = LISTEN_PORT
    if len(sys.argv) > 1: port = int(sys.argv[1])
    print("=" * 55)
    print("  GEMMI Proxy v18 — FULLY SELF-CONTAINED")
    print("  dbRoot: LOCAL | Auth: LOCAL | Tiles: kh.google.com")
    print("  Listening on 0.0.0.0:%d" % port)
    print("=" * 55)
    print()
    server = http.server.HTTPServer(("0.0.0.0", port), Handler)
    try: server.serve_forever()
    except KeyboardInterrupt: print("\nStopped."); server.server_close()

if __name__ == "__main__": main()

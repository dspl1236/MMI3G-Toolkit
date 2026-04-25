#!/usr/bin/env python3
"""GEMMI Proxy v17 — kh.google.com for data, xgx for auth"""
import http.server, os, urllib.request, urllib.error, ssl, sys, re, hashlib

LISTEN_PORT = 80
GOOGLE = "https://kh.google.com"
XGX = "http://xgx.ddns.net"
UA = "GoogleEarth/7.3.6.9796(Windows;Microsoft Windows (6.2.9200.0);en;kml:2.2;client:Free;type:default)"
UA_GEMMI = "GoogleEarth/5.2.0000.6394(MMI3G;QNX (0.0.0.0);en-US;kml:2.2;client:Free;type:default)"
CACHE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tile_cache")
os.makedirs(CACHE_DIR, exist_ok=True)
CTX = ssl.create_default_context()

def cache_get(key):
    p = os.path.join(CACHE_DIR, key)
    if os.path.exists(p):
        with open(p, "rb") as f: return f.read()
    return None

def cache_put(key, data):
    with open(os.path.join(CACHE_DIR, key), "wb") as f: f.write(data)

def fetch(upstream, method, path, body=None, ua=UA):
    ck = hashlib.md5((upstream + method + path).encode()).hexdigest()
    if method == "GET":
        cached = cache_get("c_" + ck)
        if cached: return cached
    try:
        url = upstream + path
        req = urllib.request.Request(url, data=body, method=method)
        req.add_header("User-Agent", ua)
        if body: req.add_header("Content-Type", "application/octet-stream")
        if upstream.startswith("https"):
            data = urllib.request.urlopen(req, context=CTX, timeout=15).read()
        else:
            data = urllib.request.urlopen(req, timeout=15).read()
        if method == "GET" and len(data) > 2: cache_put("c_" + ck, data)
        return data
    except Exception as e:
        print("[ERR]   %s" % e); return None

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): pass
    def do_POST(self):
        cl = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(cl) if cl > 0 else b""
        if '/geauth' in self.path:
            # Auth goes to xgx (Google doesn't have /geauth)
            data = fetch(XGX, "POST", self.path, body, UA_GEMMI)
            if data:
                print("[AUTH]  (%db) -> %db xgx" % (cl, len(data)))
            else:
                cmd = body[4:5] if len(body) > 4 else b"\x03"
                data = cmd + b"\x00" * 15
                print("[AUTH]  (%db) -> 16b local" % cl)
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
        if '/dbRoot' in path or '/flatfile' in path:
            # Rewrite dbRoot URL for Google (strip cobrand=AUDI etc)
            if '/dbRoot' in path:
                # dbRoot from xgx (works with GEMMI)
                data = fetch(XGX, "GET", path, ua=UA_GEMMI)
            else:
                # Tiles and QT from Google
                data = fetch(GOOGLE, "GET", path, ua=UA)
            if data and len(data) > 2:
                tag = "ROOT" if '/dbRoot' in path else "QT  " if 'q2' in query else "TILE" if re.match(r'f\d+', query) else "FLAT"
                print("[%s]  %s -> %db GOOGLE" % (tag, query[:50], len(data)))
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
    print("  GEMMI Proxy v17 — kh.google.com DIRECT!")
    print("  Data: kh.google.com (REAL Google Earth)")
    print("  Auth: xgx.ddns.net")
    print("  Listening on 0.0.0.0:%d" % port)
    print("=" * 55)
    print()
    server = http.server.HTTPServer(("0.0.0.0", port), Handler)
    try: server.serve_forever()
    except KeyboardInterrupt: print("\nStopped."); server.server_close()

if __name__ == "__main__": main()

#!/usr/bin/env python3
"""GEMMI Proxy v19 — 100% self-owned. Custom dbRoot. Zero xgx."""
import http.server, os, urllib.request, urllib.error, ssl, sys, re, hashlib

LISTEN_PORT = 80
GOOGLE = "https://kh.google.com"
UA = "GoogleEarth/7.3.6.9796(Windows;Microsoft Windows (6.2.9200.0);en;kml:2.2;client:Free;type:default)"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR = os.path.join(BASE_DIR, "tile_cache")
os.makedirs(CACHE_DIR, exist_ok=True)
CTX = ssl.create_default_context()

with open(os.path.join(BASE_DIR, "dbRoot_custom.bin"), "rb") as f: DBROOT = f.read()
with open(os.path.join(BASE_DIR, "auth_resp1.bin"), "rb") as f: AUTH1 = f.read()
with open(os.path.join(BASE_DIR, "auth_resp2.bin"), "rb") as f: AUTH2 = f.read()
print("  Custom dbRoot: %d bytes | Auth: %d+%d bytes" % (len(DBROOT), len(AUTH1), len(AUTH2)))

def cache_get(k):
    p = os.path.join(CACHE_DIR, k)
    return open(p,"rb").read() if os.path.exists(p) else None
def cache_put(k, d):
    with open(os.path.join(CACHE_DIR, k), "wb") as f: f.write(d)
def fetch_google(path):
    ck = hashlib.md5(path.encode()).hexdigest()
    c = cache_get("g_"+ck)
    if c: return c
    try:
        d = urllib.request.urlopen(urllib.request.Request(
            GOOGLE+path, headers={"User-Agent":UA}), context=CTX, timeout=15).read()
        if len(d)>2: cache_put("g_"+ck, d)
        return d
    except Exception as e: print("[ERR] %s"%e); return None

class H(http.server.BaseHTTPRequestHandler):
    def log_message(s,*a): pass
    def do_POST(s):
        cl=int(s.headers.get('Content-Length',0)); body=s.rfile.read(cl) if cl>0 else b""
        if '/geauth' in s.path:
            d=AUTH2 if cl>=49 else AUTH1; print("[AUTH] (%db)->%db"%(cl,len(d)))
            s.send_response(200); s.send_header("Content-Type","application/octet-stream")
            s.send_header("Content-Length",str(len(d))); s.end_headers(); s.wfile.write(d); return
        s.send_response(200); s.end_headers()
    def do_GET(s):
        p=s.path; q=p.split("?",1)[1] if "?" in p else ""
        if '/dbRoot' in p:
            print("[ROOT] Custom dbRoot (%db)"%len(DBROOT)); s.send_response(200)
            s.send_header("Content-Type","application/octet-stream")
            s.send_header("Content-Length",str(len(DBROOT))); s.end_headers(); s.wfile.write(DBROOT); return
        if '/flatfile' in p:
            d=fetch_google(p)
            if d and len(d)>2:
                t="QT" if 'q2' in q else "TILE" if re.match(r'f\d+',q) else "FLAT"
                print("[%-4s] %s -> %db"%(t,q[:50],len(d))); s.send_response(200)
                s.send_header("Content-Type","application/octet-stream")
                s.send_header("Content-Length",str(len(d))); s.end_headers(); s.wfile.write(d)
            else: s.send_response(404); s.end_headers()
            return
        s.send_response(200); s.send_header("Content-Length","0"); s.end_headers()

if __name__=="__main__":
    port=int(sys.argv[1]) if len(sys.argv)>1 else LISTEN_PORT
    print("="*55); print("  GEMMI Proxy v19 | Custom dbRoot | kh.google.com")
    print("  Listening on 0.0.0.0:%d"%port); print("="*55); print()
    http.server.HTTPServer(("0.0.0.0",port),H).serve_forever()

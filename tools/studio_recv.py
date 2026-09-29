# Studio HttpService 결과 수신기. POST /name -> recv/name.txt
import http.server, os, time
OUT = os.environ.get("RECV_DIR") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "recv")
os.makedirs(OUT, exist_ok=True)
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n)
        name = self.path.strip("/").replace("/", "_") or "post"
        with open(os.path.join(OUT, name + ".txt"), "wb") as f:
            f.write(body)
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(("127.0.0.1", 34999), H).serve_forever()

#!/usr/bin/env python3
"""Sirve el export web de Godot con los headers COOP/COEP requeridos para SharedArrayBuffer."""
import http.server
import os

PORT = 8080
DIRECTORY = os.path.join(os.path.dirname(__file__), "exports", "web")


class CORSHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def log_message(self, format, *args):
        pass  # silencia el log


if __name__ == "__main__":
    with http.server.HTTPServer(("localhost", PORT), CORSHandler) as httpd:
        print(f"Servidor en http://localhost:{PORT}")
        httpd.serve_forever()

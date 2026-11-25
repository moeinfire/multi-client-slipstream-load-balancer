#!/usr/bin/env python3
"""Per-tunnel SOCKS5 gateway: local RFC1929 authentication + Slipstream relay."""
import json
import socket
import socketserver
import sys
import threading

def recv_exact(sock, size):
    data = bytearray()
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise ConnectionError("client disconnected during SOCKS5 handshake")
        data.extend(chunk)
    return bytes(data)

class Gateway:
    def __init__(self, config):
        self.cfg = config
        self.auth = bool(config.get("auth_enabled"))
        self.username = config.get("username", "").encode("utf-8")
        self.password = config.get("password", "").encode("utf-8")
        if self.auth and (not self.username or not self.password or len(self.username) > 255 or len(self.password) > 255):
            raise ValueError("invalid SOCKS5 credentials in gateway config")

    def handle(self, client):
        upstream = None
        try:
            client.settimeout(30)
            head = recv_exact(client, 2)
            if head[0] != 5:
                return
            methods = recv_exact(client, head[1])
            required = 2 if self.auth else 0
            if required not in methods:
                client.sendall(b"\x05\xff")
                return
            client.sendall(bytes((5, required)))
            if self.auth:
                version = recv_exact(client, 1)
                if version != b"\x01":
                    return
                ulen = recv_exact(client, 1)[0]
                user = recv_exact(client, ulen)
                plen = recv_exact(client, 1)[0]
                password = recv_exact(client, plen)
                import hmac
                valid = hmac.compare_digest(user, self.username) and hmac.compare_digest(password, self.password)
                client.sendall(b"\x01\x00" if valid else b"\x01\x01")
                if not valid:
                    return
            upstream = socket.create_connection((self.cfg["upstream_host"], int(self.cfg["upstream_port"])), timeout=15)
            upstream.settimeout(30)
            # Re-negotiate the same method with the remote SOCKS5 endpoint.
            upstream.sendall(bytes((5, 1, required)))
            reply = recv_exact(upstream, 2)
            if reply != bytes((5, required)):
                return
            if self.auth:
                upstream.sendall(b"\x01" + bytes((len(self.username),)) + self.username + bytes((len(self.password),)) + self.password)
                if recv_exact(upstream, 2) != b"\x01\x00":
                    return
            # Forward the SOCKS CONNECT request and all subsequent application bytes.
            request = client.recv(4096)
            if not request:
                return
            upstream.sendall(request)
            sockets = (client, upstream)
            while True:
                readable, _, _ = __import__("select").select(sockets, (), (), 60)
                if not readable:
                    break
                for source in readable:
                    data = source.recv(65536)
                    if not data:
                        return
                    (upstream if source is client else client).sendall(data)
        except (OSError, ConnectionError, ValueError):
            pass
        finally:
            if upstream:
                try: upstream.close()
                except OSError: pass
            try: client.close()
            except OSError: pass

class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        self.server.gateway.handle(self.request)

class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

def main(path):
    with open(path, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    gateway = Gateway(cfg)
    server = Server((cfg.get("listen_host", "127.0.0.1"), int(cfg["listen_port"])), Handler)
    server.gateway = gateway
    server.serve_forever(poll_interval=0.5)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: socks5-gateway.py /etc/slipstream-panel/tunnels/ID.json")
    main(sys.argv[1])

#!/usr/bin/env python3
"""SOCKS5 gateway that negotiates authentication end-to-end like the DNS scanner."""
import json
import select
import socket
import socketserver
import sys


def recv_exact(sock, size):
    data = bytearray()
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise ConnectionError("peer disconnected during SOCKS5 exchange")
        data.extend(chunk)
    return bytes(data)


def read_request(sock):
    head = recv_exact(sock, 4)
    if head[0] != 5:
        raise ValueError("invalid SOCKS version")
    atyp = head[3]
    if atyp == 1:
        tail = recv_exact(sock, 6)
    elif atyp == 4:
        tail = recv_exact(sock, 18)
    elif atyp == 3:
        size = recv_exact(sock, 1)
        tail = size + recv_exact(sock, size[0] + 2)
    else:
        raise ValueError("unsupported SOCKS address type")
    return head + tail


def relay(client, upstream):
    sockets = (client, upstream)
    while True:
        readable, _, _ = select.select(sockets, (), (), 60)
        if not readable:
            return
        for source in readable:
            data = source.recv(65536)
            if not data:
                return
            (upstream if source is client else client).sendall(data)


class Gateway:
    def __init__(self, config):
        self.cfg = config
        self.panel_auth = bool(config.get("auth_enabled"))
        # Keep the configured credentials validated as before. The actual
        # RFC1929 exchange is passed through to the far-end SOCKS server,
        # exactly as the scanner does; the client supplies these credentials.
        username = config.get("username", "").encode("utf-8")
        password = config.get("password", "").encode("utf-8")
        if self.panel_auth and (
            not username or not password or
            len(username) > 255 or len(password) > 255
        ):
            raise ValueError("invalid SOCKS5 credentials in gateway config")

    def handle(self, client):
        upstream = None
        client.settimeout(30)
        try:
            greeting = recv_exact(client, 2)
            if greeting[0] != 5 or greeting[1] == 0:
                return
            client_methods = list(recv_exact(client, greeting[1]))

            # Match the scanner's behavior: when panel auth is enabled, require
            # RFC1929; otherwise negotiate any supported method the client
            # offered, preferring username/password and then no-auth.
            if self.panel_auth:
                methods = [2] if 2 in client_methods else []
            else:
                methods = [method for method in (2, 0) if method in client_methods]
            if not methods:
                client.sendall(b"\x05\xff")
                return

            upstream = socket.create_connection(
                (self.cfg["upstream_host"], int(self.cfg["upstream_port"])),
                timeout=15
            )
            upstream.settimeout(30)

            # Send the exact SOCKS5 method offer upstream, as the scanner does.
            upstream.sendall(bytes((5, len(methods), *methods)))
            upstream_method = recv_exact(upstream, 2)
            if upstream_method[0] != 5 or upstream_method[1] not in methods:
                client.sendall(b"\x05\xff")
                return

            # Report the method selected by the actual remote SOCKS5 server.
            client.sendall(upstream_method)

            if upstream_method[1] == 2:
                # Forward the complete RFC1929 exchange unchanged. This keeps
                # both panel-configured and client-supplied credentials working
                # through the tunnel without terminating auth at this gateway.
                auth_head = recv_exact(client, 2)
                if auth_head[0] != 1 or auth_head[1] == 0:
                    return
                username = recv_exact(client, auth_head[1])
                plen = recv_exact(client, 1)[0]
                if plen == 0:
                    return
                password = recv_exact(client, plen)
                upstream.sendall(auth_head + username + bytes((plen,)) + password)

                auth_reply = recv_exact(upstream, 2)
                client.sendall(auth_reply)
                if auth_reply != b"\x01\x00":
                    return

            # Relay the SOCKS CONNECT request and all subsequent traffic.
            request = read_request(client)
            upstream.sendall(request)
            relay(client, upstream)

        except (OSError, ConnectionError, ValueError):
            try:
                client.sendall(b"\x05\x01\x00\x01\x00\x00\x00\x00\x00\x00")
            except OSError:
                pass
        finally:
            if upstream:
                try:
                    upstream.close()
                except OSError:
                    pass
            try:
                client.close()
            except OSError:
                pass


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        self.server.gateway.handle(self.request)


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main(path):
    with open(path, "r", encoding="utf-8") as source:
        config = json.load(source)
    gateway = Gateway(config)
    server = Server(
        (config.get("listen_host", "127.0.0.1"), int(config["listen_port"])),
        Handler
    )
    server.gateway = gateway
    server.serve_forever(poll_interval=0.5)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: socks5-gateway.py /etc/slipstream-panel/tunnels/ID.json")
    main(sys.argv[1])

#!/usr/bin/env python3
"""Per-tunnel SOCKS5 gateway with local RFC1929 auth and Slipstream relay."""
import hmac
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
        tail = recv_exact(sock, 4 + 2)
    elif atyp == 4:
        tail = recv_exact(sock, 16 + 2)
    elif atyp == 3:
        size = recv_exact(sock, 1)
        tail = size + recv_exact(sock, size[0] + 2)
    else:
        raise ValueError("unsupported SOCKS address type")
    return head + tail


def failure_reply():
    return b"\x05\x01\x00\x01\x00\x00\x00\x00\x00\x00"


class Gateway:
    def __init__(self, config):
        self.cfg = config
        self.auth = bool(config.get("auth_enabled"))
        self.username = config.get("username", "").encode("utf-8")
        self.password = config.get("password", "").encode("utf-8")
        if self.auth and (not self.username or not self.password or
                          len(self.username) > 255 or len(self.password) > 255):
            raise ValueError("invalid SOCKS5 credentials in gateway config")

    def handle(self, client):
        upstream = None
        client.settimeout(30)
        try:
            greeting = recv_exact(client, 2)
            if greeting[0] != 5 or greeting[1] == 0:
                return
            methods = recv_exact(client, greeting[1])
            required = 2 if self.auth else 0
            if required not in methods:
                client.sendall(b"\x05\xff")
                return

            # Verify that the far-end SOCKS5 endpoint supports the same mode
            # before telling the local client that a method was selected.
            upstream = socket.create_connection(
                (self.cfg["upstream_host"], int(self.cfg["upstream_port"])),
                timeout=15
            )
            upstream.settimeout(30)
            upstream.sendall(bytes((5, 1, required)))
            if recv_exact(upstream, 2) != bytes((5, required)):
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
                valid = (hmac.compare_digest(user, self.username) and
                         hmac.compare_digest(password, self.password))
                if not valid:
                    client.sendall(b"\x01\x01")
                    return
                upstream.sendall(
                    b"\x01" + bytes((len(self.username),)) + self.username +
                    bytes((len(self.password),)) + self.password
                )
                if recv_exact(upstream, 2) != b"\x01\x00":
                    client.sendall(b"\x01\x01")
                    return
                client.sendall(b"\x01\x00")

            # Read and forward one complete SOCKS request; TCP recv() is not
            # guaranteed to return the entire request in a single call.
            request = read_request(client)
            upstream.sendall(request)

            sockets = (client, upstream)
            while True:
                readable, _, _ = select.select(sockets, (), (), 60)
                if not readable:
                    break
                for source in readable:
                    data = source.recv(65536)
                    if not data:
                        return
                    (upstream if source is client else client).sendall(data)
        except (OSError, ConnectionError, ValueError):
            try:
                client.sendall(failure_reply())
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

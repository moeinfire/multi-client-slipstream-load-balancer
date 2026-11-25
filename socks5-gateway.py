#!/usr/bin/env python3
"""SOCKS5 gateway: trusted no-auth client ingress, authenticated remote egress."""
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


def failure_reply():
    return b"\x05\x01\x00\x01\x00\x00\x00\x00\x00\x00"


class Gateway:
    def __init__(self, config):
        self.cfg = config
        self.username = config.get("username", "").encode("utf-8")
        self.password = config.get("password", "").encode("utf-8")
        self.upstream_auth = bool(config.get("auth_enabled"))
        if self.upstream_auth and (
            not self.username or not self.password or
            len(self.username) > 255 or len(self.password) > 255
        ):
            raise ValueError("invalid upstream SOCKS5 credentials in gateway config")

    def handle(self, client):
        upstream = None
        client.settimeout(30)
        try:
            greeting = recv_exact(client, 2)
            if greeting[0] != 5 or greeting[1] == 0:
                return
            methods = recv_exact(client, greeting[1])
            if 0 not in methods:
                client.sendall(b"\x05\xff")
                return

            upstream = socket.create_connection(
                (self.cfg["upstream_host"], int(self.cfg["upstream_port"])),
                timeout=15
            )
            upstream.settimeout(30)

            # Negotiate independently with the remote SOCKS5 server.
            method = 2 if self.upstream_auth else 0
            upstream.sendall(bytes((5, 1, method)))
            if recv_exact(upstream, 2) != bytes((5, method)):
                client.sendall(b"\x05\xff")
                return

            # The client never needs the remote server's credentials.
            client.sendall(b"\x05\x00")

            if self.upstream_auth:
                upstream.sendall(
                    b"\x01" + bytes((len(self.username),)) + self.username +
                    bytes((len(self.password),)) + self.password
                )
                if recv_exact(upstream, 2) != b"\x01\x00":
                    client.sendall(failure_reply())
                    return

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

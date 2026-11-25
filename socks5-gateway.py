#!/usr/bin/env python3
"""SOCKS5 gateway with independent local and upstream authentication.

If panel credentials are configured, clients must authenticate with those
credentials and the gateway uses them upstream. If panel credentials are empty,
the client's selected SOCKS5 method and RFC1929 credentials are negotiated
with and forwarded to the remote SOCKS5 server.
"""
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
    return b"\x05\x01\x00\x01\x00\x00\x00\x00\x00"


def read_credentials(sock):
    version = recv_exact(sock, 1)
    if version != b"\x01":
        raise ValueError("invalid RFC1929 version")
    ulen = recv_exact(sock, 1)[0]
    if ulen == 0:
        raise ValueError("empty SOCKS5 username")
    username = recv_exact(sock, ulen)
    plen = recv_exact(sock, 1)[0]
    if plen == 0:
        raise ValueError("empty SOCKS5 password")
    password = recv_exact(sock, plen)
    return username, password


def send_credentials(sock, username, password):
    sock.sendall(
        b"\x01" + bytes((len(username),)) + username +
        bytes((len(password),)) + password
    )


class Gateway:
    def __init__(self, config):
        self.cfg = config
        self.username = config.get("username", "").encode("utf-8")
        self.password = config.get("password", "").encode("utf-8")
        self.panel_auth = bool(config.get("auth_enabled"))
        if self.panel_auth and (
            not self.username or not self.password or
            len(self.username) > 255 or len(self.password) > 255
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

            # Configured panel credentials retain the original protected mode.
            # Otherwise, negotiate whichever method the client and upstream
            # can both use, preferring username/password when offered.
            if self.panel_auth:
                offered = [2] if 2 in client_methods else []
            else:
                offered = [m for m in (2, 0) if m in client_methods]
            if not offered:
                client.sendall(b"\x05\xff")
                return

            upstream = socket.create_connection(
                (self.cfg["upstream_host"], int(self.cfg["upstream_port"])),
                timeout=15
            )
            upstream.settimeout(30)
            upstream.sendall(bytes((5, len(offered), *offered)))
            upstream_choice = recv_exact(upstream, 2)
            if upstream_choice[0] != 5 or upstream_choice[1] not in offered:
                client.sendall(b"\x05\xff")
                return

            method = upstream_choice[1]
            client.sendall(bytes((5, method)))

            if method == 2:
                client_user, client_password = read_credentials(client)
                if self.panel_auth:
                    valid = (
                        hmac.compare_digest(client_user, self.username) and
                        hmac.compare_digest(client_password, self.password)
                    )
                    if not valid:
                        client.sendall(b"\x01\x01")
                        return
                    upstream_user, upstream_password = self.username, self.password
                else:
                    # No panel credentials: transparently pass the client's
                    # RFC1929 credentials to the upstream SOCKS5 service.
                    upstream_user, upstream_password = client_user, client_password

                send_credentials(upstream, upstream_user, upstream_password)
                auth_reply = recv_exact(upstream, 2)
                client.sendall(auth_reply)
                if auth_reply != b"\x01\x00":
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

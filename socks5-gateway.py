#!/usr/bin/env python3
"""SOCKS5 gateway supporting both panel authentication and client credential passthrough."""
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
    return b"\x05\x01\x00\x01\x00\x00\x00\x00\x00\x00"


def read_credentials(sock):
    if recv_exact(sock, 1) != b"\x01":
        raise ValueError("invalid RFC1929 version")
    ulen = recv_exact(sock, 1)[0]
    if not ulen:
        raise ValueError("empty SOCKS5 username")
    username = recv_exact(sock, ulen)
    plen = recv_exact(sock, 1)[0]
    if not plen:
        raise ValueError("empty SOCKS5 password")
    password = recv_exact(sock, plen)
    return username, password


def send_credentials(sock, username, password):
    if not (1 <= len(username) <= 255 and 1 <= len(password) <= 255):
        raise ValueError("SOCKS5 credentials must be 1..255 bytes")
    sock.sendall(
        b"\x01" + bytes((len(username),)) + username +
        bytes((len(password),)) + password
    )


def negotiate_upstream(upstream, methods):
    # Preserve preference order: username/password first, then no-auth.
    unique = []
    for method in methods:
        if method in (2, 0) and method not in unique:
            unique.append(method)
    if not unique:
        raise ValueError("no common SOCKS5 authentication method")
    upstream.sendall(bytes((5, len(unique), *unique)))
    reply = recv_exact(upstream, 2)
    if reply[0] != 5 or reply[1] not in unique:
        raise PermissionError("upstream rejected available SOCKS5 methods")
    return reply[1]


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

            if self.panel_auth:
                # Mode A: authenticate the external client against panel
                # credentials locally. Do not expose upstream negotiation
                # details to the client.
                if 2 not in client_methods:
                    client.sendall(b"\x05\xff")
                    return
                client.sendall(b"\x05\x02")
                client_user, client_password = read_credentials(client)
                valid = (
                    hmac.compare_digest(client_user, self.username) and
                    hmac.compare_digest(client_password, self.password)
                )
                if not valid:
                    client.sendall(b"\x01\x01")
                    return
                client.sendall(b"\x01\x00")

                upstream = socket.create_connection(
                    (self.cfg["upstream_host"], int(self.cfg["upstream_port"])),
                    timeout=15
                )
                upstream.settimeout(30)
                upstream_method = negotiate_upstream(upstream, [2, 0])

                # Keep compatibility with authenticated remote SOCKS servers:
                # use panel credentials if upstream asks for RFC1929; if it
                # selects no-auth, do not send an unnecessary auth packet.
                if upstream_method == 2:
                    send_credentials(upstream, self.username, self.password)
                    if recv_exact(upstream, 2) != b"\x01\x00":
                        client.sendall(failure_reply())
                        return

            else:
                # Mode B: no credentials configured in panel. Negotiate with
                # upstream using only methods the external client offered,
                # then pass RFC1929 credentials through unchanged if selected.
                methods = [m for m in (2, 0) if m in client_methods]
                if not methods:
                    client.sendall(b"\x05\xff")
                    return
                upstream = socket.create_connection(
                    (self.cfg["upstream_host"], int(self.cfg["upstream_port"])),
                    timeout=15
                )
                upstream.settimeout(30)
                upstream_method = negotiate_upstream(upstream, methods)
                client.sendall(bytes((5, upstream_method)))

                if upstream_method == 2:
                    client_user, client_password = read_credentials(client)
                    send_credentials(upstream, client_user, client_password)
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

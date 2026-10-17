# /// script
# requires-python = ">=3.11"
# dependencies = ["aiohttp>=3.12,<4", "typer>=0.12,<1", "websockets>=15,<16"]
# ///
"""Run with: uv run helper_scripts/tests/test_msg_bridge_web.py"""
import asyncio
from contextlib import suppress
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path
import socket
import sqlite3
import ssl
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

from aiohttp import ClientSession, ClientConnectorError, CookieJar
from aiohttp.test_utils import TestClient, TestServer
import websockets

loader = SourceFileLoader("msg_bridge", str(Path(__file__).resolve().parents[1] / "bin/msg-bridge"))
bridge = module_from_spec(spec_from_loader(loader.name, loader))
loader.exec_module(bridge)


class WebTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.messages = []

        async def forward(message):
            self.messages.append(message)
            return 2

        self.client = TestClient(TestServer(bridge.web_app("test-password", forward, lambda: [])))
        await self.client.start_server()

    async def asyncTearDown(self):
        await self.client.close()

    async def login(self):
        response = await self.client.post('/send/api/login', json={'password': 'test-password'})
        self.assertEqual(response.status, 200)
        cookie = response.cookies[bridge.SESSION_COOKIE]
        self.assertTrue(cookie['secure'])
        self.assertTrue(cookie['httponly'])
        self.assertEqual(cookie['samesite'], 'Strict')
        self.assertEqual(int(cookie['max-age']), bridge.SESSION_AGE)
        return {'Cookie': f'{bridge.SESSION_COOKIE}={cookie.value}'}

    async def test_page_and_assets_have_no_password_or_cache(self):
        for path in ("/send/", "/send/app.js", "/send/style.css"):
            response = await self.client.get(path)
            self.assertEqual(response.status, 200)
            self.assertEqual(response.headers["Cache-Control"], "no-store")
            self.assertNotIn("test-password", await response.text())
        self.assertEqual((await self.client.get("/send/other.js")).status, 404)

    async def test_unauthorized_and_cross_origin_requests_do_not_forward(self):
        self.assertEqual((await self.client.get('/send/api/messages')).status, 401)
        for headers in ({}, {"X-Bridge-Password": "wrong"}):
            response = await self.client.post("/send/api/messages", json={"message": "hello"}, headers=headers)
            self.assertEqual(response.status, 401)
        response = await self.client.options("/send/api/messages", headers={
            "Origin": "https://other.example", "Access-Control-Request-Headers": "X-Bridge-Password",
        })
        self.assertNotIn("Access-Control-Allow-Origin", response.headers)
        self.assertEqual(self.messages, [])

    async def test_unicode_message_is_forwarded_once_without_modification(self):
        message = " 你好\n第二行 😀 "
        response = await self.client.post("/send/api/messages", json={"message": message},
                                          headers=await self.login())
        self.assertEqual(response.status, 200)
        self.assertEqual(await response.json(), {"receivers": 2})
        self.assertEqual(self.messages, [message])

    async def test_invalid_inputs_and_size_limit(self):
        headers = await self.login()
        for payload in ({}, [], {"message": 42}, {"message": "\n "}, {"message": bridge.RECEIVER}):
            response = await self.client.post("/send/api/messages", json=payload, headers=headers)
            self.assertEqual(response.status, 400)
        response = await self.client.post("/send/api/messages", data="{", headers={
            **headers, "Content-Type": "application/json",
        })
        self.assertEqual(response.status, 400)
        response = await self.client.post("/send/api/messages", data="hello", headers=headers)
        self.assertEqual(response.status, 415)
        response = await self.client.post("/send/api/messages", json={"message": "a" * (1024 * 1024)}, headers=headers)
        self.assertEqual(response.status, 413)
        self.assertEqual(self.messages, [])

    async def test_login_session_logout_and_bad_password(self):
        response = await self.client.post('/send/api/login', json={'password': 'wrong'})
        self.assertEqual(response.status, 401)
        self.assertNotIn(bridge.SESSION_COOKIE, response.cookies)
        self.assertEqual((await self.client.get('/send/api/session')).status, 401)
        headers = await self.login()
        self.assertEqual((await self.client.get('/send/api/session', headers=headers)).status, 200)
        response = await self.client.post('/send/api/logout', json={}, headers=headers)
        self.assertEqual(response.status, 200)
        self.assertEqual(response.cookies[bridge.SESSION_COOKIE]['max-age'], '0')
        self.assertEqual((await self.client.get('/send/api/session')).status, 401)

    async def test_expired_tampered_and_password_rotated_sessions_are_rejected(self):
        with patch.object(bridge.time, 'time', return_value=time.time() - bridge.SESSION_AGE - 10):
            expired = await self.login()
        self.assertEqual((await self.client.get('/send/api/session', headers=expired)).status, 401)
        headers = await self.login()
        tampered = {'Cookie': headers['Cookie'] + 'x'}
        self.assertEqual((await self.client.get('/send/api/session', headers=tampered)).status, 401)
        async def forward(message):
            self.fail('Session check must not forward messages')
        # Same password preserves login across service restarts.
        for password, expected in [('test-password', 200), ('rotated-password', 401)]:
            async with TestClient(TestServer(bridge.web_app(password, forward, lambda: []))) as client:
                self.assertEqual((await client.get('/send/api/session', headers=headers)).status, expected)


def unused_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class BridgeIntegrationTests(unittest.IsolatedAsyncioTestCase):
    async def test_https_to_archive_and_websocket_receiver(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cert, key = root / "cert.pem", root / "key.pem"
            subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                            "-keyout", str(key), "-out", str(cert), "-days", "1",
                            "-subj", "/CN=localhost", "-addext", "subjectAltName=IP:127.0.0.1"],
                           check=True, capture_output=True)
            ws_port, https_port = unused_port(), unused_port()
            db, password_file = root / "messages.sqlite3", root / "password"
            task = asyncio.create_task(bridge.bridge_loop(
                "127.0.0.1", ws_port, db, web_port=https_port, password_file=password_file,
                web_cert=cert, web_key=key,
            ))
            context = ssl.create_default_context(cafile=str(cert))
            try:
                async with ClientSession(cookie_jar=CookieJar(unsafe=True)) as client:
                    base = f"https://127.0.0.1:{https_port}/send/"
                    for attempt in range(100):
                        if task.done():
                            await task
                        try:
                            response = await client.get(base, ssl=context)
                            break
                        except ClientConnectorError:
                            if attempt == 99:
                                raise
                            await asyncio.sleep(.02)
                    self.assertEqual(response.status, 200)
                    password = password_file.read_text().strip()
                    self.assertEqual(password_file.stat().st_mode & 0o777, 0o600)
                    self.assertEqual(bridge.web_password(password_file), password)
                    response = await client.post(base + 'api/login', json={'password': password}, ssl=context)
                    self.assertEqual(response.status, 200)
                    headers = {}
                    # Offline sends are archived, and explicitly report zero receivers.
                    response = await client.post(base + "api/messages", json={"message": "offline"},
                                                 headers=headers, ssl=context)
                    self.assertEqual(await response.json(), {"receivers": 0})
                    async with websockets.connect(f"ws://127.0.0.1:{ws_port}") as receiver:
                        await receiver.send(bridge.RECEIVER)
                        # A ping round trip ensures registration was processed before HTTP send.
                        await (await receiver.ping())
                        response = await client.post(base + "api/messages", json={"message": "网页测试\nhello"},
                                                     headers=headers, ssl=context)
                        self.assertEqual(await response.json(), {"receivers": 1})
                        self.assertEqual(await asyncio.wait_for(receiver.recv(), 2), "网页测试\nhello")
                        async with websockets.connect(f"ws://127.0.0.1:{ws_port}") as sender:
                            await sender.send("existing CLI")
                            self.assertEqual(await asyncio.wait_for(receiver.recv(), 2), "existing CLI")
                        response = await client.get(base + 'api/messages', ssl=context)
                        history = (await response.json())['messages']
                        self.assertEqual([row['content'] for row in history], ['existing CLI', '网页测试\nhello', 'offline'])
                        self.assertGreater(history[0]['id'], history[-1]['id'])
                        self.assertTrue(all(row['received_at'] for row in history))
                        # Clicking a history item posts the exact archived content through the same API.
                        response = await client.post(base + 'api/messages', json={'message': history[1]['content']}, ssl=context)
                        self.assertEqual(await response.json(), {'receivers': 1})
                        self.assertEqual(await asyncio.wait_for(receiver.recv(), 2), '网页测试\nhello')
                    with sqlite3.connect(db) as connection:
                        rows = connection.execute("SELECT content FROM messages ORDER BY id").fetchall()
                        self.assertEqual(rows, [("offline",), ("网页测试\nhello",), ("existing CLI",), ('网页测试\nhello',)])
                        connection.executemany(
                            'INSERT INTO messages (received_at, content, char_count, byte_count) VALUES (?, ?, ?, ?)',
                            [('2026-10-18T00:00:00+00:00', f'older-{index}', 8, 8) for index in range(55)],
                        )
                        connection.commit()
                    response = await client.get(base + 'api/messages', ssl=context)
                    history = (await response.json())['messages']
                    self.assertEqual(len(history), 50)
                    self.assertEqual(history[0]['content'], 'older-54')
                    self.assertEqual(history[-1]['content'], 'older-5')
            finally:
                task.cancel()
                with suppress(asyncio.CancelledError):
                    await task

    async def test_public_plaintext_and_partial_tls_fail_before_startup(self):
        with tempfile.TemporaryDirectory() as directory:
            db = Path(directory) / "messages.sqlite3"
            for options in ({"web_host": "0.0.0.0"}, {"web_cert": Path("missing.pem")}):
                with self.assertRaises(ValueError):
                    await bridge.bridge_loop("127.0.0.1", 0, db, web_port=8766, **options)
            self.assertFalse(db.exists())


if __name__ == "__main__":
    unittest.main()

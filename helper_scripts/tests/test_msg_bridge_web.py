# /// script
# requires-python = ">=3.11"
# dependencies = ["aiohttp>=3.12,<4", "typer>=0.12,<1", "websockets>=15,<16"]
# ///
"""Run with: uv run helper_scripts/tests/test_msg_bridge_web.py"""
import asyncio
import base64
import hashlib
import html
import json
from contextlib import suppress
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path
import re
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
        self.submissions = []

        async def forward(message, submit, request_id):
            self.messages.append(message)
            self.submissions.append(submit)
            return {"receivers": 2}

        self.client = TestClient(TestServer(bridge.web_app("test-password", forward, lambda: [], lambda request_id: None, lambda: [], lambda message, request_id: {"id": request_id, "content": message}, lambda request_id: None, lambda: [], lambda message: {}, lambda favorite_id: None)))
        await self.client.start_server()

    async def asyncTearDown(self):
        await self.client.close()

    async def login(self):
        response = await self.client.post('/send/api/login', json={'password': 'test-password'})
        self.assertEqual(response.status, 200)
        cookie = response.cookies[bridge.SESSION_COOKIE]
        self.assertTrue(cookie['secure'])
        self.assertTrue(cookie['httponly'])
        self.assertEqual(cookie['samesite'], 'Lax')
        self.assertTrue(cookie['expires'])
        self.assertEqual(int(cookie['max-age']), bridge.SESSION_AGE)
        return {'Cookie': f'{bridge.SESSION_COOKIE}={cookie.value}'}

    async def test_favorite_input_validation(self):
        headers = await self.login()
        for value in (None, '', '  ', 42, bridge.RECEIVER):
            response = await self.client.post('/send/api/favorites', json={'message': value}, headers=headers)
            self.assertEqual(response.status, 400)
        for value in ('0', '-1', 'abc', '999999999999999999999999'):
            response = await self.client.delete('/send/api/favorites/' + value, headers=headers)
            self.assertEqual(response.status, 400)

    async def test_page_and_assets_have_no_password_or_cache(self):
        for path in ("/send/", "/send/app.js", "/send/style.css"):
            response = await self.client.get(path)
            self.assertEqual(response.status, 200)
            self.assertEqual(response.headers["Cache-Control"], "no-store")
            self.assertNotIn("test-password", await response.text())
        self.assertEqual((await self.client.get("/send/other.js")).status, 404)

    async def test_single_response_bootstrap_keeps_history_private_and_escaped(self):
        headers = await self.login()
        history_calls = []
        content = '</template><script>alert("history-xss")</script>\n正文 & <b>'
        messages = [{'id': 1, 'received_at': '2026-10-18T00:00:00Z', 'content': content}]
        def history():
            history_calls.append(True)
            return messages
        async def forward(message, submit, request_id):
            self.fail('Page loading must not send messages')
        async with TestClient(TestServer(bridge.web_app('test-password', forward, history, lambda request_id: None, lambda: [], lambda message, request_id: {"id": request_id, "content": message}, lambda request_id: None, lambda: [], lambda message: {}, lambda favorite_id: None))) as client:
            response = await client.get('/send/')
            page = await response.text()
            state = json.loads(html.unescape(re.search(r'<template id="initial-state">(.*?)</template>', page, re.S)[1]))
            self.assertEqual(state, {'authenticated': False})
            self.assertEqual(history_calls, [])
            response = await client.get('/send/', headers=headers)
            page = await response.text()
            state = json.loads(html.unescape(re.search(r'<template id="initial-state">(.*?)</template>', page, re.S)[1]))
            self.assertEqual(state, {'authenticated': True, 'messages': messages, 'saved': [], 'favorites': []})
            self.assertNotIn(content, page)
            self.assertNotIn('src="./app.js"', page)
            self.assertNotIn('href="./style.css"', page)
            for tag in ('script', 'style'):
                inline = re.search(f'<{tag}>(.*?)</{tag}>', page, re.S)[1]
                digest = base64.b64encode(hashlib.sha256(inline.encode()).digest()).decode()
                self.assertIn(f"'sha256-{digest}'", response.headers['Content-Security-Policy'])

    async def test_unauthorized_and_cross_origin_requests_do_not_forward(self):
        self.assertEqual((await self.client.get('/send/api/messages')).status, 401)
        self.assertEqual((await self.client.post('/send/api/saved', json={})).status, 401)
        self.assertEqual((await self.client.delete('/send/api/saved/' + 'e' * 32)).status, 401)
        self.assertEqual((await self.client.post('/send/api/favorites', json={'message': 'secret'})).status, 401)
        self.assertEqual((await self.client.delete('/send/api/favorites/1')).status, 401)
        self.assertEqual((await self.client.get('/send/api/requests/' + 'a' * 32)).status, 401)
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
        for payload in ({}, [], {"message": 42}, {"message": "\n "}, {"message": bridge.RECEIVER}, {"message": "text", "submit": "false"}):
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

    async def test_receipts_reject_invalid_ids_and_report_missing_requests(self):
        headers = await self.login()
        for request_id in (123, '', 'x' * 32, 'a' * 31):
            response = await self.client.post('/send/api/messages', json={'message': 'text', 'request_id': request_id}, headers=headers)
            self.assertEqual(response.status, 400)
        self.assertEqual((await self.client.get('/send/api/requests/' + 'a' * 32, headers=headers)).status, 404)
        self.assertEqual(self.messages, [])

    async def test_save_validates_input_without_forwarding(self):
        headers = await self.login()
        for payload in ({}, {'message': ' '}, {'message': bridge.RECEIVER, 'request_id': 'c' * 32},
                        {'message': 'draft', 'request_id': 'invalid'}):
            response = await self.client.post('/send/api/saved', json=payload, headers=headers)
            self.assertEqual(response.status, 400)
        response = await self.client.post('/send/api/saved', json={'message': 'draft', 'request_id': 'c' * 32}, headers=headers)
        self.assertEqual(response.status, 200)
        self.assertEqual((await response.json())['content'], 'draft')
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
        async def forward(message, submit, request_id):
            self.fail('Session check must not forward messages')
        # Same password preserves login across service restarts.
        for password, expected in [('test-password', 200), ('rotated-password', 401)]:
            async with TestClient(TestServer(bridge.web_app(password, forward, lambda: [], lambda request_id: None, lambda: [], lambda message, request_id: {"id": request_id, "content": message}, lambda request_id: None, lambda: [], lambda message: {}, lambda favorite_id: None))) as client:
                self.assertEqual((await client.get('/send/api/session', headers=headers)).status, expected)

    async def test_session_slides_on_page_refresh_and_expires_only_after_inactivity(self):
        start = time.time()
        with patch.object(bridge.time, 'time', return_value=start):
            original = await self.login()
        with patch.object(bridge.time, 'time', return_value=start + 29 * 86400):
            response = await self.client.get('/send/', headers=original)
            self.assertEqual(response.headers['X-Bridge-Authenticated'], '1')
            cookie = response.cookies[bridge.SESSION_COOKIE]
            self.assertEqual(cookie['samesite'], 'Lax')
            self.assertEqual(cookie['path'], '/send/')
            self.assertEqual(int(cookie['max-age']), 30 * 86400)
            renewed = {'Cookie': f'{bridge.SESSION_COOKIE}={cookie.value}'}
        with patch.object(bridge.time, 'time', return_value=start + 58 * 86400):
            response = await self.client.get('/send/api/messages', headers=renewed)
            self.assertEqual(response.status, 200)
            cookie = response.cookies[bridge.SESSION_COOKIE]
            latest = {'Cookie': f'{bridge.SESSION_COOKIE}={cookie.value}'}
        # A fresh app instance preserves the same login after an ordinary service restart.
        async def forward(message, submit, request_id):
            self.fail('Session check must not send messages')
        async with TestClient(TestServer(bridge.web_app('test-password', forward, lambda: [], lambda request_id: None,
                                                     lambda: [], lambda message, request_id: {}, lambda request_id: None, lambda: [], lambda message: {}, lambda favorite_id: None))) as client:
            with patch.object(bridge.time, 'time', return_value=start + 59 * 86400):
                response = await client.get('/send/', headers=latest)
                self.assertEqual(response.headers['X-Bridge-Authenticated'], '1')
                cookie = response.cookies[bridge.SESSION_COOKIE]
                latest = {'Cookie': f'{bridge.SESSION_COOKIE}={cookie.value}'}
            with patch.object(bridge.time, 'time', return_value=start + 90 * 86400):
                response = await client.get('/send/api/session', headers=latest)
                self.assertEqual(response.status, 401)
                self.assertNotIn(bridge.SESSION_COOKIE, response.cookies)

    async def test_logout_does_not_renew_session_and_bad_cookie_cannot_be_renewed(self):
        headers = await self.login()
        response = await self.client.post('/send/api/logout', json={}, headers=headers)
        self.assertEqual(response.cookies[bridge.SESSION_COOKIE]['max-age'], '0')
        response = await self.client.get('/send/', headers={'Cookie': f'{bridge.SESSION_COOKIE}=bad-token'})
        self.assertEqual(response.headers['X-Bridge-Authenticated'], '0')
        self.assertNotIn(bridge.SESSION_COOKIE, response.cookies)

    async def test_draft_flag_is_explicit_and_normal_send_still_submits(self):
        headers = await self.login()
        for payload in ({'message': 'draft\ntext', 'submit': False}, {'message': 'normal'}):
            response = await self.client.post('/send/api/messages', json=payload, headers=headers)
            self.assertEqual(response.status, 200)
        self.assertEqual(self.messages, ['draft\ntext', 'normal'])
        self.assertEqual(self.submissions, [False, True])


class InjectionTests(unittest.TestCase):
    def test_draft_pastes_with_bracketed_paste_and_never_presses_enter(self):
        with patch.object(bridge, 'active_pane', return_value='%test'), patch.object(bridge.subprocess, 'run') as run:
            with patch.object(bridge.time, 'sleep') as sleep:
                bridge.inject('编辑\n下一行', None, .2, submit=False)
                sleep.assert_not_called()
        commands = [call.args[0] for call in run.call_args_list]
        paste = next(command for command in commands if command[1] == 'paste-buffer')
        self.assertIn('-p', paste)
        self.assertFalse(any(command[1] == 'send-keys' for command in commands))
        self.assertEqual(commands[-1][1], 'delete-buffer')

    def test_existing_injection_still_presses_enter(self):
        with patch.object(bridge, 'active_pane', return_value='%test'), patch.object(bridge.subprocess, 'run') as run:
            with patch.object(bridge.time, 'sleep') as sleep:
                bridge.inject('normal', None, .2)
                sleep.assert_called_once_with(.2)
        self.assertIn(['tmux', 'send-keys', '-t', '%test', 'Enter'], [call.args[0] for call in run.call_args_list])


class ReceiverProtocolTests(unittest.IsolatedAsyncioTestCase):
    async def check_receiver(self, structured):
        received = asyncio.Event()
        expected = [False, True] if structured else [True]
        calls = []

        def inject(message, session, enter_delay, *, submit=True):
            calls.append((message, submit))
            if len(calls) == len(expected):
                received.set()

        async def handle(ws):
            self.assertEqual(await ws.recv(), bridge.RECEIVER)
            if structured:
                for submit in expected:
                    await ws.send(json.dumps({'message': 'draft\ntext', 'submit': submit}))
            else:
                await ws.send('{"message":"ordinary text"}')
            await ws.wait_closed()

        async with websockets.serve(handle, '127.0.0.1', 0, subprotocols=[bridge.RECEIVER_PROTOCOL] if structured else None) as server:
            port = server.sockets[0].getsockname()[1]
            with patch.object(bridge, 'inject', side_effect=inject):
                task = asyncio.create_task(bridge.receive_loop('127.0.0.1', port, 'test-session', .2))
                try:
                    await asyncio.wait_for(received.wait(), 2)
                finally:
                    task.cancel()
                    with suppress(asyncio.CancelledError):
                        await task
        self.assertEqual([call[1] for call in calls], expected)
        self.assertEqual(calls[0][0], 'draft\ntext' if structured else '{"message":"ordinary text"}')

    async def test_new_receiver_honors_submit_flag(self):
        await self.check_receiver(True)

    async def test_new_receiver_still_accepts_plain_text_from_old_bridge(self):
        await self.check_receiver(False)


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
                    saved_payload = {'message': 'save for later', 'request_id': 'c' * 32}
                    response = await client.post(base + 'api/saved', json=saved_payload, ssl=context)
                    saved_entry = await response.json()
                    self.assertEqual(saved_entry['content'], 'save for later')
                    response = await client.post(base + 'api/saved', json=saved_payload, ssl=context)
                    self.assertEqual(await response.json(), saved_entry)
                    response = await client.get(base + 'api/messages', ssl=context)
                    self.assertEqual(await response.json(), {'messages': [], 'saved': [saved_entry], 'favorites': []})
                    response = await client.get(base, ssl=context)
                    state = json.loads(html.unescape(re.search(r'<template id="initial-state">(.*?)</template>', await response.text(), re.S)[1]))
                    self.assertEqual(state['saved'], [saved_entry])
                    with sqlite3.connect(db) as connection:
                        self.assertEqual(connection.execute('SELECT content FROM saved_messages').fetchall(), [('save for later',)])
                    response = await client.post(base + 'api/favorites', json={'message': 'favorite text'}, ssl=context)
                    favorite = await response.json()
                    self.assertEqual(favorite['content'], 'favorite text')
                    response = await client.post(base + 'api/favorites', json={'message': 'favorite text'}, ssl=context)
                    self.assertEqual(await response.json(), favorite)
                    response = await client.get(base, ssl=context)
                    state = json.loads(html.unescape(re.search(r'<template id="initial-state">(.*?)</template>', await response.text(), re.S)[1]))
                    self.assertEqual(state['favorites'], [favorite])
                    with sqlite3.connect(db) as connection:
                        self.assertEqual(connection.execute('SELECT content FROM favorite_messages').fetchall(), [('favorite text',)])
                        self.assertEqual(connection.execute('SELECT COUNT(*) FROM messages').fetchone()[0], 0)
                    for _ in range(2):
                        response = await client.delete(base + 'api/favorites/' + str(favorite['id']), ssl=context)
                        self.assertEqual(response.status, 200)
                    deleted_payload = {'message': 'delete instead of sending', 'request_id': 'e' * 32}
                    response = await client.post(base + 'api/saved', json=deleted_payload, ssl=context)
                    self.assertEqual(response.status, 200)
                    for _ in range(2):
                        response = await client.delete(base + 'api/saved/' + 'e' * 32, ssl=context)
                        self.assertEqual(await response.json(), {'deleted': 'e' * 32})
                    for route in ('api/saved', 'api/messages'):
                        response = await client.post(base + route, json=deleted_payload, ssl=context)
                        self.assertEqual(response.status, 409)
                    response = await client.get(base + 'api/messages', ssl=context)
                    self.assertEqual(await response.json(), {'messages': [], 'saved': [saved_entry], 'favorites': []})
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
                        response = await client.post(base + 'api/messages', json={'message': 'must not send', 'submit': False}, ssl=context)
                        self.assertEqual(response.status, 409)
                        response = await client.post(base + 'api/messages', json={**saved_payload, 'submit': False}, ssl=context)
                        self.assertEqual(response.status, 409)
                        response = await client.get(base + 'api/messages', ssl=context)
                        self.assertEqual((await response.json())['saved'], [saved_entry])
                    async with websockets.connect(f'ws://127.0.0.1:{ws_port}', subprotocols=[bridge.RECEIVER_PROTOCOL]) as receiver:
                        self.assertEqual(receiver.subprotocol, bridge.RECEIVER_PROTOCOL)
                        await receiver.send(bridge.RECEIVER)
                        await (await receiver.ping())
                        for submit in (False, True):
                            response = await client.post(base + 'api/messages', json={'message': '编辑\n草稿', 'submit': submit}, ssl=context)
                            self.assertEqual(await response.json(), {'receivers': 1})
                            payload = json.loads(await asyncio.wait_for(receiver.recv(), 2))
                            self.assertEqual(payload, {'message': '编辑\n草稿', 'submit': submit})
                        retry_payload = {'message': 'response lost', 'submit': True, 'request_id': 'a' * 32}
                        response = await client.post(base + 'api/messages', json=retry_payload, ssl=context)
                        response.release()  # The browser may lose this response after delivery.
                        self.assertEqual(json.loads(await receiver.recv())['message'], 'response lost')
                        response = await client.get(base + 'api/requests/' + 'a' * 32, ssl=context)
                        receipt = await response.json()
                        self.assertEqual(receipt['status'], 'sent')
                        self.assertEqual(receipt['receivers'], 1)
                        response = await client.post(base + 'api/messages', json=retry_payload, ssl=context)
                        self.assertEqual(await response.json(), receipt)
                        with self.assertRaises(asyncio.TimeoutError):
                            await asyncio.wait_for(receiver.recv(), .05)
                        response = await client.post(base + 'api/favorites', json={'message': saved_payload['message']}, ssl=context)
                        kept_favorite = await response.json()
                        response = await client.post(base + 'api/messages', json=saved_payload, ssl=context)
                        saved_receipt = await response.json()
                        self.assertEqual(saved_receipt['status'], 'sent')
                        self.assertEqual(json.loads(await receiver.recv())['message'], 'save for later')
                        response = await client.get(base + 'api/messages', ssl=context)
                        converted = await response.json()
                        self.assertEqual(converted['saved'], [])
                        self.assertEqual(converted['favorites'], [kept_favorite])
                        self.assertEqual(converted['messages'][0]['content'], 'save for later')
                        response = await client.post(base + 'api/messages', json=saved_payload, ssl=context)
                        self.assertEqual(await response.json(), saved_receipt)
                        with self.assertRaises(asyncio.TimeoutError):
                            await asyncio.wait_for(receiver.recv(), .05)
                        response = await client.post(base + 'api/saved', json=saved_payload, ssl=context)
                        self.assertEqual(response.status, 409)
                        response = await client.delete(base + 'api/saved/' + 'c' * 32, ssl=context)
                        self.assertEqual(response.status, 409)
                        response = await client.post(base + 'api/messages', json={**retry_payload, 'submit': False}, ssl=context)
                        self.assertEqual(response.status, 409)

                        started, release = asyncio.Event(), asyncio.Event()
                        original_broadcast = bridge.broadcast
                        async def slow_broadcast(receivers, message, submit=True):
                            started.set()
                            await release.wait()
                            return await original_broadcast(receivers, message, submit)
                        pending_payload = {'message': 'pending delivery', 'request_id': 'b' * 32}
                        with patch.object(bridge, 'broadcast', side_effect=slow_broadcast):
                            first = asyncio.ensure_future(client.post(base + 'api/messages', json=pending_payload, ssl=context))
                            try:
                                await asyncio.wait_for(started.wait(), 2)
                                response = await client.get(base + 'api/requests/' + 'b' * 32, ssl=context)
                                self.assertEqual((await response.json())['status'], 'pending')
                                response = await client.post(base + 'api/messages', json=pending_payload, ssl=context)
                                self.assertEqual(response.status, 202)
                                self.assertEqual((await response.json())['status'], 'pending')
                            finally:
                                release.set()
                            response = await first
                            self.assertEqual((await response.json())['status'], 'sent')
                        self.assertEqual(json.loads(await receiver.recv())['message'], 'pending delivery')
                        with self.assertRaises(asyncio.TimeoutError):
                            await asyncio.wait_for(receiver.recv(), .05)
                    with sqlite3.connect(db) as connection:
                        rows = connection.execute("SELECT content FROM messages ORDER BY id").fetchall()
                        self.assertEqual(rows, [("offline",), ("网页测试\nhello",), ("existing CLI",), ('网页测试\nhello',), ('编辑\n草稿',), ('编辑\n草稿',), ('response lost',), ('save for later',), ('pending delivery',)])
                        stored = connection.execute('SELECT request_id, receivers FROM web_requests ORDER BY request_id').fetchall()
                        self.assertEqual(stored, [('a' * 32, 1), ('b' * 32, 1), ('c' * 32, 1)])
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

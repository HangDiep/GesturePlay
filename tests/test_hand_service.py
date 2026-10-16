"""Kiểm tra giao thức Python -> Flutter qua WebSocket thật, camera giả lập."""

import asyncio
import json
import sys
import time
import unittest

from websockets.asyncio.client import connect
from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed

from core.shared_state import HandResult, SharedState
from hand_service.server import HandServer


class FakeRuntime:
    def __init__(self):
        self.state = SharedState()
        self.state.set_camera_status("running", "Camera giả lập")
        self.state.set_tracker_status("running", "Nhận diện giả lập")
        self.running = True
        self.clean_shutdown = True
        self.closing = False
        self.stops = 0

    def ensure_started(self):
        pass

    def request_stop(self):
        self.stops += 1

    def shutdown(self):
        return True

    def hand(self, frame, ratio):
        now = time.monotonic_ns()
        self.state.publish_hand(HandResult(now // 1_000_000, frame, now, now, .5, .5, ratio))


class ServiceTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.runtime = FakeRuntime()
        self.service = HandServer(runtime=self.runtime, idle_timeout=0)
        self.server = await serve(self.service.handler, "127.0.0.1", 0, origins=[None], max_size=4096)
        self.uri = f"ws://127.0.0.1:{self.server.sockets[0].getsockname()[1]}"

    async def asyncTearDown(self):
        self.server.close()
        await self.server.wait_closed()

    async def packet(self, socket, kind="hand", predicate=lambda packet: True):
        for _ in range(30):
            message = await asyncio.wait_for(socket.recv(), 2)
            if isinstance(message, str):
                packet = json.loads(message)
                if packet.get("type") == kind and predicate(packet):
                    return packet
        self.fail("Không nhận được packet mong đợi")

    async def test_status_protocol_and_single_owner(self):
        async with connect(self.uri) as first:
            packet = await self.packet(first)
            self.assertEqual(packet["protocol"], 1)
            self.assertFalse(packet["valid"])
            async with connect(self.uri) as other:
                with self.assertRaises(ConnectionClosed):
                    await other.recv()

    async def test_jump_is_latched_and_disconnect_stops_runtime(self):
        async with connect(self.uri) as socket:
            await socket.send(json.dumps({"type": "command", "action": "start"}))
            self.runtime.hand(1, .8)
            await self.packet(socket, predicate=lambda p: p["released"])
            self.runtime.hand(2, .1)
            pressed = await self.packet(socket, predicate=lambda p: p["jump_id"] == 1)
            self.assertTrue(pressed["pinched"])
            again = await self.packet(socket)
            self.assertEqual(again["jump_id"], 1)
        await asyncio.sleep(.05)
        self.assertGreater(self.runtime.stops, 0)

    async def test_invalid_commands_cannot_execute_code_or_start_game(self):
        async with connect(self.uri) as socket:
            await socket.send(json.dumps({"type": "command", "action": "run_python", "path": "anything.py"}))
            packet = await self.packet(socket, "error")
            self.assertIn("message", packet)
            self.assertFalse(self.service.active)
            await socket.send(json.dumps({"type": "command", "action": "start", "camera_index": -1}))
            await self.packet(socket, "error")
            self.assertFalse(self.service.active)


if __name__ == "__main__":
    unittest.main()

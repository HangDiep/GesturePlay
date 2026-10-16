"""Chỉ đăng ký những trò đã triển khai; không thực thi mã do server cung cấp."""

from client.games.runner import RunnerGame

GAME_TYPES = {"runner": RunnerGame}

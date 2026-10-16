"""Vật lý độc lập giao diện: bước nhỏ cố định, chướng ngại có khoảng cách an toàn."""

from dataclasses import dataclass
import math
import random
import uuid

from client.games.base_game import GameResult


@dataclass(frozen=True)
class RunnerRules:
    label: str
    speed: float
    min_gap: float
    max_gap: float
    max_spikes: int
    spike_height: int
    time_limit: float = 120.0


RULES = {
    "easy": RunnerRules("Dễ", 290, 650, 850, 1, 44),
    "normal": RunnerRules("Vừa", 350, 610, 790, 2, 52),
    "hard": RunnerRules("Khó", 410, 580, 750, 3, 60),
}


@dataclass
class Obstacle:
    x: float
    spikes: int
    height: float
    passed: bool = False

    @property
    def width(self) -> int:
        return self.spikes * 28


@dataclass
class Coin:
    x: float
    y: float
    collected: bool = False


def triangle_hits_box(triangle, box) -> bool:
    """SAT cho gai tam giác và hitbox chữ nhật, tránh va chạm ở góc trống."""
    left, top, width, height = box
    rectangle = ((left, top), (left + width, top),
                 (left + width, top + height), (left, top + height))
    axes = [(1, 0), (0, 1)]
    for index, point in enumerate(triangle):
        other = triangle[(index + 1) % 3]
        axes.append((point[1] - other[1], other[0] - point[0]))
    for ax, ay in axes:
        a = [x * ax + y * ay for x, y in triangle]
        b = [x * ax + y * ay for x, y in rectangle]
        if max(a) <= min(b) or max(b) <= min(a):
            return False
    return True


class RunnerGame:
    code = "runner"
    width = 1120
    ground_y = 548
    player_x = 190
    player_width = 46
    player_height = 64
    gravity = 1900.0
    jump_velocity = -720.0

    def __init__(self, difficulty="normal", control_mode="hand", seed=None):
        if difficulty not in RULES or control_mode not in {"hand", "keyboard"}:
            raise ValueError("Độ khó hoặc kiểu điều khiển không hợp lệ.")
        self.difficulty = difficulty
        self.control_mode = control_mode
        self.rules = RULES[difficulty]
        self._random = random.Random(seed)
        self.reset()

    def reset(self):
        self.session_id = str(uuid.uuid4())  # ID local, không giả làm session của backend.
        self.distance = 0.0
        self.elapsed = 0.0
        self.player_y = float(self.ground_y)
        self.velocity_y = 0.0
        self.obstacles_passed = 0
        self.coins_collected = 0
        self.obstacles: list[Obstacle] = []
        self.coins: list[Coin] = []
        self._next_spawn_x = self.width + 160.0
        self.started = False
        self.paused = False
        self.outcome: str | None = None
        self._spawn_ahead()

    @property
    def score(self):
        return 10 * self.obstacles_passed + 20 * self.coins_collected

    @property
    def grounded(self):
        return self.player_y >= self.ground_y and self.velocity_y >= 0

    @property
    def speed(self):
        return self.rules.speed + min(35, self.elapsed * 0.35)

    @property
    def finished(self):
        return self.outcome is not None

    @property
    def hitbox(self):
        return (self.player_x + 8, self.player_y - self.player_height + 8,
                self.player_width - 16, self.player_height - 10)

    def start(self):
        if not self.finished:
            self.started = True
            self.paused = False

    def pause(self):
        self.paused = True

    def jump(self) -> bool:
        if not self.started or self.paused or self.finished or not self.grounded:
            return False
        self.velocity_y = self.jump_velocity
        return True

    def _spawn_ahead(self):
        while self._next_spawn_x - self.distance < self.width + 260:
            spikes = self._random.randint(1, self.rules.max_spikes)
            obstacle = Obstacle(self._next_spawn_x, spikes, self.rules.spike_height)
            self.obstacles.append(obstacle)
            for index in range(5):
                fraction = index / 4
                self.coins.append(Coin(obstacle.x - 125 + fraction * (250 + obstacle.width),
                                       self.ground_y - 70 - 80 * math.sin(fraction * math.pi)))
            for index in range(2):
                self.coins.append(Coin(obstacle.x + obstacle.width + 210 + index * 46,
                                       self.ground_y - 28))
            self._next_spawn_x += self._random.uniform(self.rules.min_gap, self.rules.max_gap)

    def update(self, dt: float, jump_pressed=False):
        if not self.started or self.paused or self.finished:
            return
        if not math.isfinite(dt) or dt < 0:
            raise ValueError("Delta thời gian phải hữu hạn và không âm.")
        if jump_pressed:
            self.jump()
        remaining = min(dt, 0.25)
        while remaining > 1e-9 and not self.finished:
            step = min(remaining, 1 / 120, self.rules.time_limit - self.elapsed)
            if step <= 1e-9:
                self.outcome = "time_up"
                break
            self.elapsed += step
            self.distance += self.speed * step
            if not self.grounded or self.velocity_y < 0:
                self.player_y += self.velocity_y * step + 0.5 * self.gravity * step * step
                self.velocity_y += self.gravity * step
                if self.player_y >= self.ground_y:
                    self.player_y = float(self.ground_y)
                    self.velocity_y = 0.0
            self._spawn_ahead()
            self._collisions()
            if not self.finished and self.elapsed >= self.rules.time_limit - 1e-8:
                self.elapsed = self.rules.time_limit
                self.outcome = "time_up"
            remaining -= step
        self.obstacles = [o for o in self.obstacles if o.x + o.width - self.distance > -80]
        self.coins = [c for c in self.coins if not c.collected and c.x - self.distance > -30]

    def _collisions(self):
        left, top, width, height = self.hitbox
        for obstacle in self.obstacles:
            x = obstacle.x - self.distance
            if x + obstacle.width < left:
                if not obstacle.passed:
                    obstacle.passed = True
                    self.obstacles_passed += 1
                continue
            if x > left + width:
                continue
            for index in range(obstacle.spikes):
                spike_x = x + index * 28
                triangle = ((spike_x, self.ground_y),
                            (spike_x + 14, self.ground_y - obstacle.height),
                            (spike_x + 28, self.ground_y))
                if triangle_hits_box(triangle, self.hitbox):
                    self.outcome = "lost"
                    return
        for coin in self.coins:
            if coin.collected:
                continue
            x = coin.x - self.distance
            closest_x = min(left + width, max(left, x))
            closest_y = min(top + height, max(top, coin.y))
            if (x - closest_x) ** 2 + (coin.y - closest_y) ** 2 <= 12 ** 2:
                coin.collected = True
                self.coins_collected += 1

    def get_result(self) -> GameResult:
        if not self.finished:
            raise RuntimeError("Ván chưa kết thúc.")
        return GameResult(
            self.session_id, self.code, self.difficulty, 1, self.outcome,
            self.score, round(self.elapsed * 1000),
            {"obstacles_passed": self.obstacles_passed,
             "coins_collected": self.coins_collected,
             "distance_units": int(self.distance / 10)}, self.control_mode,
        )

"""Đồ họa 2D tự vẽ, không tải sprite và không chạy mô hình trong vòng render."""

import math
import textwrap

import cv2
import pygame

from client.core.scene_manager import Scene
from client.games.runner import RULES


NAVY = (20, 38, 51)
MUTED = (104, 126, 137)
WHITE = (250, 253, 249)
TEAL = (19, 145, 130)
MINT = (127, 230, 192)
ORANGE = (244, 144, 77)
GOLD = (255, 201, 76)


class RunnerScreen:
    def __init__(self, config):
        self.config = config
        pygame.display.init()
        pygame.font.init()
        self.screen = pygame.display.set_mode((1120, 700))
        pygame.display.set_caption("GesturePlay · Sky Runner")
        self.clock = pygame.time.Clock()
        self.fonts = {size: pygame.font.SysFont("segoeui", size, bold=size >= 28)
                      for size in (13, 14, 16, 18, 20, 24, 28, 32, 40, 48, 64, 96)}
        self.buttons = {}
        self.preview_enabled = config.preview_enabled
        self.show_metrics = False
        self.focused = True
        self._preview = None
        self._thumbnail = None
        self._preview_id = -1
        self._preview_at_ns = 0
        self._state_identity = None

    def text(self, value, position, size=18, color=NAVY, center=False):
        surface = self.fonts[size].render(str(value), True, color)
        rect = surface.get_rect(center=position) if center else surface.get_rect(topleft=position)
        self.screen.blit(surface, rect)

    def lines(self, value, position, width=50, size=16, color=MUTED, line_height=25, limit=4):
        for index, line in enumerate(textwrap.wrap(value, width=width)[:limit]):
            self.text(line, (position[0], position[1] + index * line_height), size, color)

    def panel(self, rect, color=WHITE, border=None, radius=20):
        pygame.draw.rect(self.screen, color, rect, border_radius=radius)
        if border:
            pygame.draw.rect(self.screen, border, rect, 1, border_radius=radius)

    def button(self, action, label, rect, enabled=True, primary=False, selected=False):
        rect = pygame.Rect(rect)
        self.buttons[action] = (rect, enabled)
        hover = enabled and rect.collidepoint(pygame.mouse.get_pos())
        color = TEAL if primary or selected else (230, 239, 234)
        if not enabled:
            color = (215, 223, 221)
        elif hover:
            color = (15, 123, 112) if primary or selected else (211, 228, 220)
        self.panel(rect, color, radius=12)
        self.text(label, rect.center, 16,
                  WHITE if enabled and (primary or selected) else MUTED if not enabled else NAVY, center=True)

    def events(self):
        actions = []
        jump = False
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                actions.append("quit")
            elif event.type == pygame.WINDOWFOCUSLOST:
                self.focused = False
            elif event.type == pygame.WINDOWFOCUSGAINED:
                self.focused = True
            elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                for action, (rect, enabled) in reversed(tuple(self.buttons.items())):
                    if enabled and rect.collidepoint(event.pos):
                        actions.append(action)
                        break
            elif event.type == pygame.KEYDOWN and not getattr(event, "repeat", False):
                if event.key in (pygame.K_SPACE, pygame.K_UP):
                    jump = True
                elif event.key == pygame.K_ESCAPE:
                    actions.append("escape")
                elif event.key == pygame.K_p:
                    actions.append("pause_toggle")
                elif event.key == pygame.K_RETURN:
                    actions.append("enter")
                elif event.key == pygame.K_r:
                    actions.append("restart")
                elif event.key == pygame.K_v:
                    self.preview_enabled = not self.preview_enabled
                elif event.key == pygame.K_F3:
                    self.show_metrics = not self.show_metrics
                elif event.key == pygame.K_F1:
                    actions.append("calibrate_open")
                elif event.key == pygame.K_F2:
                    actions.append("calibrate_closed")
        return actions, jump

    def _background(self, distance=0):
        self.screen.fill((223, 244, 238))
        pygame.draw.circle(self.screen, (255, 227, 161), (942, 164), 68)
        pygame.draw.circle(self.screen, (255, 235, 188), (942, 164), 47)
        for x, y, scale in ((90, 180, 1.0), (530, 145, 0.7), (1000, 282, 0.8)):
            x = (x - distance * 0.07) % 1300 - 90
            for dx, dy, radius in ((0, 0, 22), (28, -12, 30), (58, 0, 24)):
                pygame.draw.circle(self.screen, (246, 252, 241),
                                   (round(x + dx * scale), round(y + dy * scale)), round(radius * scale))
        offset = distance * 0.13 % 650
        for index in range(-1, 4):
            x = index * 650 - offset
            pygame.draw.polygon(self.screen, (158, 206, 194),
                                [(x, 500), (x + 170, 281), (x + 320, 400), (x + 470, 267), (x + 650, 500)])
            pygame.draw.polygon(self.screen, (192, 226, 213),
                                [(x + 170, 281), (x + 119, 346), (x + 178, 327), (x + 222, 343)])
        offset = distance * 0.32 % 400
        for index in range(-1, 5):
            x = index * 400 - offset
            pygame.draw.ellipse(self.screen, (100, 166, 145), (x, 424, 480, 190))
        pygame.draw.rect(self.screen, (52, 119, 99), (0, 532, 1120, 24))
        pygame.draw.rect(self.screen, (103, 165, 115), (0, 548, 1120, 10))
        pygame.draw.rect(self.screen, (182, 134, 92), (0, 558, 1120, 142))
        pygame.draw.rect(self.screen, (200, 154, 107), (0, 558, 1120, 20))
        for index in range(32):
            x = (index * 43 - distance * 0.9) % 1180 - 30
            y = 595 + (index % 3) * 21
            pygame.draw.line(self.screen, (159, 117, 84), (x, y), (x + 13, y), 3)

    def _character(self, x, feet, elapsed, grounded=True):
        height = 548 - feet
        shadow_width = max(18, 50 - height * 0.15)
        pygame.draw.ellipse(self.screen, (53, 111, 92), (x + 23 - shadow_width / 2, 543, shadow_width, 8))
        bob = math.sin(elapsed * 18) * 2 if grounded else 0
        top = round(feet - 64 + bob)
        x = round(x)
        pygame.draw.polygon(self.screen, ORANGE, [(x + 8, top + 31), (x - 21, top + 30), (x - 8, top + 42)])
        pygame.draw.rect(self.screen, TEAL, (x + 5, top + 25, 36, 31), border_radius=8)
        pygame.draw.rect(self.screen, (44, 186, 161), (x, top, 46, 35), border_radius=12)
        pygame.draw.rect(self.screen, NAVY, (x + 10, top + 9, 31, 17), border_radius=6)
        pygame.draw.rect(self.screen, MINT, (x + 27, top + 13, 5, 6), border_radius=2)
        pygame.draw.rect(self.screen, MINT, (x + 15, top + 13, 5, 6), border_radius=2)
        pygame.draw.circle(self.screen, GOLD, (x + 31, top + 43), 4)
        stride = math.sin(elapsed * 20) * 6 if grounded else 4
        for dx, shift in ((10, stride), (28, -stride)):
            pygame.draw.rect(self.screen, NAVY, (x + dx, round(feet - 12 + shift * .25), 11, 12), border_radius=4)

    def _world(self, game):
        self._background(game.distance if game else 0)
        if game:
            for coin in game.coins:
                if coin.collected:
                    continue
                x = round(coin.x - game.distance)
                if -20 < x < 1140:
                    width = round(5 + 8 * abs(math.sin(game.elapsed * 5 + coin.x * .01)))
                    pygame.draw.ellipse(self.screen, (190, 132, 40), (x - width, coin.y - 13, width * 2, 26))
                    pygame.draw.ellipse(self.screen, GOLD, (x - width + 2, coin.y - 11, max(2, width * 2 - 4), 22))
                    pygame.draw.line(self.screen, (255, 244, 190), (x, coin.y - 6), (x, coin.y + 5), 2)
            for obstacle in game.obstacles:
                x = obstacle.x - game.distance
                if x > 1150 or x + obstacle.width < -20:
                    continue
                for index in range(obstacle.spikes):
                    sx = x + index * 28
                    points = [(sx, 548), (sx + 14, 548 - obstacle.height), (sx + 28, 548)]
                    pygame.draw.polygon(self.screen, (94, 70, 114), points)
                    pygame.draw.polygon(self.screen, (147, 108, 160),
                                        [(sx + 14, 548 - obstacle.height), (sx + 14, 548), (sx + 28, 548)])
            self._character(game.player_x, game.player_y, game.elapsed, game.grounded)
        else:
            self._character(794, 548, 0)
            for x in (902, 930):
                pygame.draw.polygon(self.screen, (94, 70, 114), [(x, 548), (x + 14, 496), (x + 28, 548)])
            for x, y in ((875, 416), (922, 396), (969, 416)):
                pygame.draw.circle(self.screen, GOLD, (x, y), 12)

    def _shade(self):
        veil = pygame.Surface((1120, 700), pygame.SRCALPHA)
        veil.fill((12, 30, 39, 145))
        self.screen.blit(veil, (0, 0))

    def _menu(self, manager):
        self.panel((48, 120, 564, 522), NAVY)
        self.text("01 / SKY RUNNER", (80, 151), 16, MINT)
        self.text("Chạy. Nhảy.", (78, 186), 48, WHITE)
        self.text("Vượt giới hạn.", (78, 246), 48, WHITE)
        self.lines("Robot tự chạy, bạn chọn đúng thời điểm nhảy. Tránh gai và gom xu trong hành trình 120 giây.",
                   (80, 322), width=57, color=(187, 208, 209), size=16)
        self.text("CHỌN ĐỘ KHÓ", (80, 405), 13, MINT)
        for index, (code, rules) in enumerate(RULES.items()):
            self.button("difficulty_" + code, rules.label, (80 + index * 160, 435, 146, 42),
                        selected=manager.difficulty == code)
        self.button("play_hand", "Chơi bằng bàn tay", (80, 501, 468, 48), primary=True)
        self.button("play_keyboard", "Luyện bằng bàn phím", (80, 560, 296, 44))
        self.button("quit", "Thoát", (390, 560, 158, 44))
        if manager.scores.error:
            self.text(manager.scores.error, (80, 616), 13, GOLD)
        self.panel((661, 128, 408, 178), WHITE)
        self.text("Một cử chỉ, một cú nhảy", (687, 151), 24)
        self.lines("Chụm ngón cái và ngón trỏ để nhảy. Thả ra trước lần nhảy tiếp theo.", (688, 199), width=42)
        best = manager.scores.best(manager.difficulty, "hand")
        self.text(f"Kỷ lục bằng tay trên máy: {best}", (688, 266), 14, TEAL)
        self.panel((661, 595, 408, 47), WHITE)
        self.text("+10 vượt gai     +20 thu xu", (688, 607), 18)

    def _preview_image(self, state, now_ns):
        if self._state_identity is not state.frame and state.frame is None:
            self._preview = None
            self._thumbnail = None
            self._preview_id = -1
        frame = state.frame
        if frame is not None and (frame.frame_id != self._preview_id or self._preview is None):
            if now_ns - self._preview_at_ns >= 1_000_000_000 / self.config.preview_fps:
                small = cv2.resize(frame.bgr, (320, 240), interpolation=cv2.INTER_AREA)
                rgb = cv2.cvtColor(small, cv2.COLOR_BGR2RGB)
                self._preview = pygame.image.frombuffer(rgb.tobytes(), (320, 240), "RGB")
                self._thumbnail = pygame.transform.scale(self._preview, (224, 168))
                self._preview_id = frame.frame_id
                self._preview_at_ns = now_ns
        self._state_identity = state.frame

    def _camera_view(self, rect, state, gesture, now_ns, small=False):
        rect = pygame.Rect(rect)
        self._preview_image(state, now_ns)
        surface = self._thumbnail if small else self._preview
        if surface is None:
            return
        self.screen.blit(surface, rect)
        if gesture.valid and state.hand is not None and state.hand.pinch_points:
            coordinates = state.hand.pinch_points
            if all(math.isfinite(value) for point in coordinates for value in point):
                points = [(round(rect.x + x * rect.width), round(rect.y + y * rect.height))
                          for x, y in coordinates]
                old_clip = self.screen.get_clip()
                self.screen.set_clip(rect)
                color = GOLD if gesture.pinched else MINT
                pygame.draw.line(self.screen, color, *points, 3)
                for point in points:
                    pygame.draw.circle(self.screen, NAVY, point, 7)
                    pygame.draw.circle(self.screen, color, point, 5)
                self.screen.set_clip(old_clip)
        if gesture.valid:
            self.panel((rect.x + 6, rect.bottom - 31, rect.width - 12, 25), NAVY, radius=7)
            label = "ĐÃ CHỤM · THẢ HAI NGÓN" if gesture.pinched else "ĐÃ MỞ · CHỤM ĐỂ NHẢY" if gesture.released else "HÃY MỞ HAI NGÓN"
            self.text(label, (rect.x + 13, rect.bottom - 27), 13, GOLD if gesture.pinched else MINT)

    def _gesture_practice(self, gesture, now_ns):
        self.panel((142, 410, 470, 121), (232, 242, 234), radius=12)
        self.text("THỬ CỬ CHỈ", (158, 422), 13, TEAL)
        self.button("calibrate_reset", "Mặc định", (504, 417, 94, 29))
        recent_jump = gesture.last_jump_ns is not None and now_ns - gesture.last_jump_ns < 750_000_000
        message = ("Đã nhận chụm → lệnh nhảy!" if recent_jump else
                   "Đã nhận chụm · thả hai ngón" if gesture.pinched else
                   "Đã mở · chụm thử hai ngón" if gesture.released else "Đưa tay vào rồi mở hai ngón")
        self.text(message, (158, 447), 20, TEAL if gesture.valid else MUTED)
        self.lines(gesture.calibration_message, (158, 480), width=58, size=14,
                   line_height=20, limit=2)

    def _preparing(self, manager, gesture, state, now_ns, closing):
        self._shade()
        self.panel((104, 120, 912, 510))
        keyboard = manager.control_mode == "keyboard"
        self.text("Sẵn sàng xuất phát", (140, 149), 32)
        self.text(f"Mức {RULES[manager.difficulty].label.lower()} · Một ván 120 giây", (142, 199), 16, MUTED)
        steps = (["SPACE hoặc ↑ để nhảy.", "Chỉ nhảy khi robot đang chạm đất.",
                  "P / Esc để tạm dừng; R để chơi lại.", "Đây là lượt luyện bằng bàn phím."] if keyboard else
                 ["1. Đưa một bàn tay vào vùng sáng rõ.", "2. Mở hai ngón, rồi chụm thử trước khi chơi.",
                  "3. Chụm chưa nhận? Ghi hai tư thế bên phải.", "Mất tay: game tự dừng, chờ bạn tiếp tục."])
        for index, line in enumerate(steps):
            self.text(line, (142, 259 + index * 37), 16)
        if keyboard:
            self.panel((652, 250, 320, 200), (229, 241, 233))
            self.text("SPACE", (812, 329), 40, TEAL, center=True)
            self.text("Nhấn để nhảy", (812, 387), 18, center=True)
        else:
            self.panel((652, 239, 320, 240), NAVY, radius=12)
            self._camera_view((652, 239, 320, 240), state, gesture, now_ns)
            if self._preview is None:
                self.text("Đang chờ camera", (812, 348), 18, WHITE, center=True)
            status = "Đang đóng phiên camera trước" if closing else gesture.reason
            if gesture.valid and not gesture.released:
                status = "Đã nhận chụm · thả ra để bắt đầu" if gesture.pinched else "Thả ngón cái và trỏ để sẵn sàng"
            self.text(status, (652, 491), 14, TEAL if gesture.ready else MUTED)
        ready = keyboard or (gesture.ready and gesture.released and not closing)
        self.button("begin", "Bắt đầu" if ready else "Đang chờ tay sẵn sàng…", (142, 547, 302, 48), ready, primary=True)
        self.button("menu", "Về menu", (460, 547, 152, 48))
        if not keyboard:
            failed = state.camera.phase == "error" or state.tracker.phase == "error"
            calibration_ready = gesture.valid and gesture.ready and not closing
            self.button("calibrate_open", "1. Ghi tay mở", (652, 547, 154, 48), calibration_ready)
            self.button("calibrate_closed", "2. Ghi tay chụm", (818, 547, 154, 48),
                        calibration_ready and gesture.calibration_stage in {"opened", "ready"})
            self.text("Hiệu chỉnh dùng trong lần mở game này.", (652, 606), 13, MUTED)
            if failed:
                self.button("camera_retry", "Thử lại camera", (652, 182, 154, 40), not closing)
                self.button("play_keyboard", "Dùng bàn phím", (818, 182, 154, 40))
                message = ("Chưa mở được webcam. Kiểm tra kết nối, quyền camera và đóng ứng dụng khác đang dùng webcam."
                           if state.camera.phase == "error" else
                           "Bộ nhận diện chưa sẵn sàng. Thử lại camera hoặc dùng bàn phím để luyện tập.")
                self.lines(message, (142, 440), width=58, size=14, color=(161, 86, 54), line_height=21, limit=4)
            else:
                self._gesture_practice(gesture, now_ns)

    def _hud(self, manager, gesture):
        game = manager.game
        self.panel((28, 24, 1064, 78), NAVY)
        self.text("SKY RUNNER", (50, 37), 24, WHITE)
        self.text(RULES[manager.difficulty].label + " · " + ("Bàn tay" if manager.control_mode == "hand" else "Bàn phím"),
                  (51, 72), 13, MINT)
        self.text(f"{game.score:04d}", (326, 34), 32, WHITE)
        self.text("ĐIỂM", (328, 74), 13, MINT)
        self.text(f"{game.coins_collected} xu", (468, 41), 24, GOLD)
        seconds = max(0, math.ceil(game.rules.time_limit - game.elapsed))
        self.text(f"{seconds // 60:02d}:{seconds % 60:02d}", (640, 36), 32, WHITE)
        status = ("SPACE để nhảy" if manager.control_mode == "keyboard" else
                  "Đã nhận chụm · thả để nhảy tiếp" if gesture.pinched else
                  "Đã mở · chụm để nhảy" if gesture.released else "Hãy mở hai ngón trước")
        self.text(status, (790, 73), 13, MINT)
        if manager.scene == Scene.PLAYING:
            self.button("pause_toggle", "Tạm dừng", (916, 36, 154, 42))

    def _pause(self, manager, gesture):
        self._shade()
        self.panel((300, 171, 520, 356))
        self.text("Tạm dừng", (560, 212), 32, center=True)
        self.lines(manager.pause_reason, (340, 257), width=50, size=16, limit=2)
        ready = manager.control_mode == "keyboard" or gesture.ready
        if manager.control_mode == "hand":
            self.text("Tay đã ổn định, có thể tiếp tục" if ready else "Đưa tay lại camera và giữ ổn định…",
                      (340, 316), 16, TEAL if ready else MUTED)
        self.button("resume", "Tiếp tục", (340, 363, 440, 48), ready and self.focused, primary=True)
        self.button("restart", "Chơi lại", (340, 429, 211, 46))
        self.button("menu", "Về menu", (569, 429, 211, 46))

    def _result(self, manager):
        self._shade()
        self.panel((262, 121, 596, 500))
        result = manager.result
        title = "Hoàn thành hành trình!" if result.outcome == "time_up" else "Thử lại một lần nữa!"
        self.text(title, (560, 168), 32, center=True)
        self.text("ĐIỂM CỦA BẠN", (560, 223), 14, TEAL, center=True)
        self.text(result.score, (560, 283), 64, center=True)
        self.panel((302, 345, 516, 80), (232, 242, 234))
        for x, value, label in ((388, result.metrics["coins_collected"], "Xu thu được"),
                                (560, result.metrics["obstacles_passed"], "Gai vượt qua"),
                                (732, f"{result.active_duration_ms / 1000:.1f}s", "Thời gian chơi")):
            self.text(value, (x, 369), 24, center=True)
            self.text(label, (x, 401), 14, MUTED, center=True)
        self.text("Đã lưu kết quả trên máy" if manager.saved else "Chưa lưu được kết quả trên máy",
                  (560, 451), 16, TEAL if manager.saved else (168, 84, 48), center=True)
        self.text("Kết quả local · chưa tham gia xếp hạng trực tuyến", (560, 480), 13, MUTED, center=True)
        self.button("restart", "Chơi lại", (302, 521, 246, 48), primary=True)
        self.button("menu", "Về menu", (566, 521, 252, 48))
        if not manager.saved:
            self.button("save_retry", "Thử lưu lại", (462, 577, 196, 32))

    def draw(self, manager, gesture, state, metrics, now_ns, closing=False):
        self.buttons = {}
        self._world(manager.game)
        if manager.scene == Scene.MENU:
            self.text("GesturePlay", (48, 30), 28)
            self.text("CHƠI BẰNG CHUYỂN ĐỘNG CỦA BẠN", (681, 45), 14, TEAL)
            self._menu(manager)
        elif manager.scene == Scene.PREPARING:
            self._preparing(manager, gesture, state, now_ns, closing)
        else:
            self._hud(manager, gesture)
            if manager.scene == Scene.PAUSED:
                self._pause(manager, gesture)
            elif manager.scene == Scene.RESULT:
                self._result(manager)
            elif manager.scene == Scene.COUNTDOWN:
                self._shade()
                self.text(max(1, math.ceil(manager.countdown)), (560, 302), 96, WHITE, center=True)
                self.text("Chuẩn bị nhảy khi gai đến gần", (560, 392), 24, WHITE, center=True)
            elif self.preview_enabled and manager.control_mode == "hand":
                self._camera_view((856, 130, 224, 168), state, gesture, now_ns, small=True)
        hints = {
            Scene.MENU: "Enter  Chuẩn bị " + ("bàn phím" if manager.control_mode == "keyboard" else "bàn tay") + "     Esc  Thoát",
            Scene.PREPARING: ("Enter  Bắt đầu khi sẵn sàng     Esc  Về menu" if manager.control_mode == "keyboard" else
                              "F1  Ghi tay mở     F2  Ghi tay chụm     Enter  Bắt đầu     Esc  Về menu"),
            Scene.PAUSED: "P / Enter  Tiếp tục khi sẵn sàng     R  Chơi lại     Esc  Về menu",
            Scene.RESULT: "R  Chơi lại     Esc  Về menu",
            Scene.COUNTDOWN: "Giữ tay sẵn sàng     Esc  Về menu",
        }
        self.text(hints.get(manager.scene, "P / Esc  Tạm dừng     R  Chơi lại     V  Camera     F3  Thông số"),
                  (30, 669), 14, WHITE)
        if self.show_metrics:
            age = "—" if metrics.result_age_ms is None else f"{metrics.result_age_ms:.0f} ms"
            self.panel((26, 622, 1068, 35), NAVY, radius=9)
            self.text(f"FPS game {metrics.ui_fps:.1f}    Camera {metrics.camera_fps:.1f}    AI {metrics.result_fps:.1f}    Độ cũ {age}",
                      (42, 629), 14, MINT)
            if manager.control_mode == "hand":
                ratio = "—" if gesture.ratio is None else f"{gesture.ratio:.2f}"
                self.text(f"Độ mở {ratio} · ngưỡng chụm {gesture.press_threshold:.2f}", (787, 629), 14, MINT)
        pygame.display.flip()

    def limit_fps(self):
        self.clock.tick(self.config.render_fps)

    def close(self):
        pygame.quit()

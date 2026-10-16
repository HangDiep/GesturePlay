"""Vẽ và xử lý sự kiện trên luồng chính, preview được cache ở 12 FPS."""

import textwrap

import cv2
import pygame

from config import AppConfig
from core.controller import ControlState
from core.metrics import MetricSnapshot
from core.shared_state import StateSnapshot


BACKGROUND = (11, 18, 31)
PANEL = (18, 29, 46)
BORDER = (37, 53, 73)
TEXT = (232, 240, 250)
MUTED = (148, 165, 186)
MINT = (91, 230, 184)
AMBER = (255, 196, 104)


class ControlDemo:
    def __init__(self, config: AppConfig, camera_only: bool = False) -> None:
        self.config = config
        self.camera_only = camera_only
        pygame.display.init()
        pygame.font.init()
        self.screen = pygame.display.set_mode((config.window_width, config.window_height))
        pygame.display.set_caption("GesturePlay · Điều khiển bằng bàn tay")
        self.clock = pygame.time.Clock()
        self.fonts = {size: pygame.font.SysFont("segoeui", size) for size in (14, 16, 18, 22, 30, 32)}
        self.play_rect = pygame.Rect(24, 122, 736, 432)
        self.side_rect = pygame.Rect(784, 122, 312, 432)
        self.preview_enabled = config.preview_enabled or camera_only
        self._preview = None
        self._preview_frame_id = -1
        self._preview_updated_ns = 0

    def _text(self, text: str, position, size=18, color=TEXT, center=False) -> None:
        surface = self.fonts[size].render(text, True, color)
        rect = surface.get_rect(center=position) if center else surface.get_rect(topleft=position)
        self.screen.blit(surface, rect)

    def _card(self, rect: pygame.Rect) -> None:
        pygame.draw.rect(self.screen, PANEL, rect, border_radius=16)
        pygame.draw.rect(self.screen, BORDER, rect, 1, border_radius=16)

    def events(self) -> bool:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return False
                if event.key == pygame.K_p:
                    self.preview_enabled = not self.preview_enabled
                    if not self.preview_enabled:
                        self._preview = None
        return True

    def _update_preview(self, state: StateSnapshot, now_ns: int) -> None:
        frame = state.frame
        if (not self.preview_enabled or frame is None
                or frame.frame_id == self._preview_frame_id
                or now_ns - self._preview_updated_ns < 1_000_000_000 / self.config.preview_fps):
            return
        small = cv2.resize(frame.bgr, (280, 210), interpolation=cv2.INTER_AREA)
        rgb = cv2.cvtColor(small, cv2.COLOR_BGR2RGB)
        self._preview = pygame.image.frombuffer(rgb.tobytes(), (280, 210), "RGB")
        self._preview_frame_id = frame.frame_id
        self._preview_updated_ns = now_ns

    @staticmethod
    def _status(control: ControlState, state: StateSnapshot, camera_only: bool):
        if state.camera.phase == "error":
            return "Không mở được camera", "Kiểm tra webcam và chạy lại ứng dụng", AMBER
        if not camera_only and state.tracker.phase == "error":
            return "Lỗi nhận diện", "Xem thông báo bên phải để xử lý", AMBER
        if camera_only:
            return "Kiểm tra camera", "Quan sát ảnh và FPS camera bên dưới", MINT
        if control.active:
            return "Đang theo dõi", "Di chuyển tay sang trái hoặc phải", MINT
        if control.reason == "stale":
            return "Tín hiệu đã cũ", "Thanh đang dừng · chờ ảnh mới", AMBER
        if state.camera.phase == "starting" or state.tracker.phase == "starting":
            return "Đang khởi tạo", "Đang mở webcam và nạp mô hình", AMBER
        return "Chưa thấy bàn tay", "Đưa một bàn tay vào trước webcam", MUTED

    def draw(self, state: StateSnapshot, control: ControlState,
             metrics: MetricSnapshot, now_ns: int) -> None:
        self._update_preview(state, now_ns)
        self.screen.fill(BACKGROUND)
        self._text("GesturePlay", (24, 22), 32)
        self._text("BẢN THỬ 01  /  ĐIỀU KHIỂN BẰNG BÀN TAY", (26, 70), 14, MUTED)
        self._text("P  Bật / tắt camera     Esc  Thoát", (795, 45), 16, MUTED)
        self._card(self.play_rect)
        self._card(self.side_rect)

        status, instruction, color = self._status(control, state, self.camera_only)
        pygame.draw.circle(self.screen, color, (50, 151), 5)
        self._text(status, (64, 136), 18, color)
        self._text("VÙNG ĐIỀU KHIỂN", (578, 142), 14, MUTED)
        for fraction in (0.25, 0.5, 0.75):
            x = self.play_rect.x + round(fraction * self.play_rect.width)
            for y in range(194, 469, 16):
                pygame.draw.circle(self.screen, BORDER, (x, y), 1)
        self._text(instruction, (self.play_rect.centerx, 225), 22, TEXT, center=True)
        self._text("Giữ lòng bàn tay hướng về camera, trong vùng sáng rõ.",
                   (self.play_rect.centerx, 262), 16, MUTED, center=True)

        if control.active and control.normalized_x is not None:
            dot_x = self.play_rect.x + self.config.paddle_width / 2 + (
                self.play_rect.width - self.config.paddle_width) * control.normalized_x
            dot_y = 308 + min(1.0, max(0.0, control.palm_y)) * 100
            pygame.draw.circle(self.screen, (35, 79, 77), (round(dot_x), round(dot_y)), 18)
            pygame.draw.circle(self.screen, MINT, (round(dot_x), round(dot_y)), 7)

        paddle = pygame.Rect(self.play_rect.x + round(control.paddle_x), 476,
                             self.config.paddle_width, self.config.paddle_height)
        pygame.draw.line(self.screen, BORDER, (40, 505), (744, 505), 1)
        pygame.draw.rect(self.screen, MINT if control.active else MUTED, paddle, border_radius=9)
        self._text("TRÁI", (44, 521), 14, MUTED)
        self._text("PHẢI", (700, 521), 14, MUTED)

        self._text("Góc camera", (800, 139), 18)
        preview_rect = pygame.Rect(800, 179, 280, 210)
        pygame.draw.rect(self.screen, BACKGROUND, preview_rect, border_radius=10)
        if self.preview_enabled and self._preview is not None:
            self.screen.blit(self._preview, preview_rect)
            # Cùng ảnh đã lật với AI; chỉ đánh dấu vùng x 0.15 đến 0.85.
            for fraction in (self.config.control_min_x, self.config.control_max_x):
                x = preview_rect.x + round(preview_rect.width * fraction)
                pygame.draw.line(self.screen, MINT, (x, preview_rect.y + 6), (x, preview_rect.bottom - 6), 1)
            if state.frame is not None and now_ns - state.frame.captured_at_ns > self.config.result_timeout_ms * 1_000_000:
                self._text("Ảnh camera đã cũ", (812, 358), 16, AMBER)
        else:
            self._text("Preview đang tắt" if not self.preview_enabled else "Đang chờ ảnh camera",
                       preview_rect.center, 18, MUTED, center=True)
            self._text("Nhấn P để bật / tắt", (940, 318), 14, MUTED, center=True)
        self._text(f"Preview {self.config.preview_fps:g} FPS · ảnh đã lật gương", (800, 401), 14, MUTED)

        message = state.camera.message
        if not self.camera_only and state.tracker.phase == "error":
            message = state.tracker.message
        for index, line in enumerate(textwrap.wrap(message, width=35)[:4]):
            self._text(line, (800, 437 + index * 22), 14,
                       AMBER if "error" in (state.camera.phase, state.tracker.phase) else MUTED)

        age = "—" if metrics.result_age_ms is None else f"{metrics.result_age_ms:.0f} ms"
        latency = "—" if metrics.callback_latency_ms is None else f"{metrics.callback_latency_ms:.0f} ms"
        entries = (
            ("GIAO DIỆN", f"{metrics.ui_fps:.1f}", "FPS vẽ thực tế"),
            ("CAMERA", f"{metrics.camera_fps:.1f}", "FPS ảnh đọc được"),
            ("KẾT QUẢ AI", f"{metrics.result_fps:.1f}", f"Gửi tối đa {self.config.detection_fps:g} FPS"),
            ("ĐỘ CŨ KẾT QUẢ", age, f"Ảnh → callback: {latency}"),
        )
        for index, (label, value, note) in enumerate(entries):
            rect = pygame.Rect(24 + index * 274, 574, 250, 102)
            self._card(rect)
            self._text(label, (rect.x + 16, rect.y + 10), 14, MUTED)
            self._text(value, (rect.x + 16, rect.y + 30), 30,
                       AMBER if index == 3 and metrics.result_age_ms is not None
                       and metrics.result_age_ms > self.config.result_timeout_ms else TEXT)
            self._text(note, (rect.x + 16, rect.y + 76), 14, MUTED)
        pygame.display.flip()

    def limit_fps(self) -> None:
        self.clock.tick(self.config.render_fps)

    def close(self) -> None:
        pygame.quit()

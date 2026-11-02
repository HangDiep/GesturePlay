import 'dart:ui' as ui;

/// Rasterize soft light once. Reusing small textures avoids running dozens of
/// radial gradient pipelines for every frame, especially on Windows Impeller.
class TownLighting {
  TownLighting._(
    this.amber,
    this.cyan,
    this.fog,
    this.shadow,
    this.damp,
    this.vignette,
    this.redEdge,
    this.hurtEdge,
    this.blackout,
    this.sky,
  );
  final ui.Image amber,
      cyan,
      fog,
      shadow,
      damp,
      vignette,
      redEdge,
      hurtEdge,
      blackout,
      sky;

  static Future<TownLighting> load() async {
    Future<ui.Image> radial(
      List<ui.Color> colors, {
      List<double>? stops,
      int side = 128,
    }) async {
      final recorder = ui.PictureRecorder();
      final c = ui.Canvas(recorder), half = side / 2;
      c.drawRect(
        ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
        ui.Paint()
          ..shader = ui.Gradient.radial(
            ui.Offset(half, half),
            half,
            colors,
            stops,
          ),
      );
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(side, side);
      } finally {
        picture.dispose();
      }
    }

    Future<ui.Image> glow(ui.Color color) =>
        radial([color, color.withValues(alpha: 0)]);
    final images = await Future.wait([
      glow(const ui.Color(0xffe7b96d)),
      glow(const ui.Color(0xff6bd3ce)),
      glow(const ui.Color(0xff73a3ad)),
      radial(
        [const ui.Color(0xff01080e), const ui.Color(0x0001080e)],
        stops: [.25, 1],
      ),
      glow(const ui.Color(0xff091923)),
      radial(
        [const ui.Color(0x0002090d), const ui.Color(0xff02090d)],
        stops: [.35, 1],
        side: 256,
      ),
      radial(
        [const ui.Color(0x00aa1019), const ui.Color(0xffaa1019)],
        stops: [.3, 1],
        side: 256,
      ),
      radial([
        const ui.Color(0x00b22d28),
        const ui.Color(0xffb22d28),
      ], side: 256),
      radial(
        [
          const ui.Color(0x0007121c),
          const ui.Color(0x6b07121c),
          const ui.Color(0xab07121c),
        ],
        stops: [.25, .72, 1],
        side: 256,
      ),
    ]);
    final recorder = ui.PictureRecorder(), size = const ui.Size(2, 256);
    ui.Canvas(recorder).drawRect(
      ui.Offset.zero & size,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset.zero,
          const ui.Offset(0, 256),
          [
            const ui.Color(0x31547c91),
            const ui.Color(0x00547c91),
            const ui.Color(0x1c040b12),
          ],
          [0, .52, 1],
        ),
    );
    final picture = recorder.endRecording();
    try {
      return TownLighting._(
        images[0],
        images[1],
        images[2],
        images[3],
        images[4],
        images[5],
        images[6],
        images[7],
        images[8],
        await picture.toImage(2, 256),
      );
    } finally {
      picture.dispose();
    }
  }

  void dispose() {
    for (final image in [
      amber,
      cyan,
      fog,
      shadow,
      damp,
      vignette,
      redEdge,
      hurtEdge,
      blackout,
      sky,
    ]) {
      image.dispose();
    }
  }
}

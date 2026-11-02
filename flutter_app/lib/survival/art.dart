import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'lighting.dart';

class TownArt {
  TownArt(
    this.ground,
    this.props,
    this.actors,
    this.stances,
    this.stanceFrames,
    this.architecture,
    this.details,
    this.architectureFrames,
    this.detailFrames,
    this.lighting,
  );
  final ui.Image ground, props, actors, stances, architecture, details;
  final List<ui.Rect> stanceFrames, architectureFrames, detailFrames;
  final TownLighting lighting;
  late final groundShader = ui.ImageShader(
    ground,
    ui.TileMode.mirror,
    ui.TileMode.mirror,
    Float64List.fromList([
      360 / ground.width,
      0,
      0,
      0,
      0,
      360 / ground.height,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
    ]),
    filterQuality: ui.FilterQuality.low,
  );

  static Future<TownArt> load() async {
    Future<ui.Image> image(String name) async {
      final bytes = await rootBundle.load('assets/town/$name.png');
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    }

    final images = await Future.wait(
      [
        'ground-v2',
        'props',
        'actors',
        'stances',
        'architecture-v2',
        'details-v2',
      ].map(image),
    );
    final data =
        jsonDecode(await rootBundle.loadString('assets/town/stances.json'))
            as Map<String, dynamic>;
    final frames = (data['frames'] as List)
        .map(
          (f) => ui.Rect.fromLTWH(
            (f[0] as num).toDouble(),
            (f[1] as num).toDouble(),
            (f[2] as num).toDouble(),
            (f[3] as num).toDouble(),
          ),
        )
        .toList();
    if (frames.length != 48 ||
        frames.any(
          (r) =>
              r.left < 0 ||
              r.top < 0 ||
              r.right > images[3].width ||
              r.bottom > images[3].height,
        )) {
      for (final i in images) {
        i.dispose();
      }
      throw const FormatException('Invalid posture atlas frames');
    }
    final environment =
        jsonDecode(
              await rootBundle.loadString('assets/town/environment-v2.json'),
            )
            as Map<String, dynamic>;
    List<ui.Rect> environmentFrames(String key, ui.Image image, int count) {
      final rects = (environment[key] as List)
          .map(
            (f) => ui.Rect.fromLTWH(
              (f[0] as num).toDouble(),
              (f[1] as num).toDouble(),
              (f[2] as num).toDouble(),
              (f[3] as num).toDouble(),
            ),
          )
          .toList();
      if (rects.length != count ||
          rects.any(
            (r) =>
                r.isEmpty ||
                r.left < 0 ||
                r.top < 0 ||
                r.right > image.width ||
                r.bottom > image.height,
          )) {
        throw const FormatException('Invalid environment atlas frames');
      }
      return rects;
    }

    try {
      return TownArt(
        images[0],
        images[1],
        images[2],
        images[3],
        frames,
        images[4],
        images[5],
        environmentFrames('architecture-v2', images[4], 6),
        environmentFrames('details-v2', images[5], 12),
        await TownLighting.load(),
      );
    } on Object {
      for (final image in images) {
        image.dispose();
      }
      rethrow;
    }
  }

  // Atlas frames have transparent padding; the art and collision footprints
  // are independent so a roof can extend above a walkable street.
  static const propFrames = [
    ui.Rect.fromLTWH(0, 0, 385, 440),
    ui.Rect.fromLTWH(390, 20, 355, 415),
    ui.Rect.fromLTWH(750, 5, 345, 440),
    ui.Rect.fromLTWH(1095, 80, 350, 365),
    ui.Rect.fromLTWH(0, 455, 450, 285),
    ui.Rect.fromLTWH(465, 450, 260, 300),
    ui.Rect.fromLTWH(815, 445, 175, 300),
    ui.Rect.fromLTWH(1130, 490, 315, 250),
    ui.Rect.fromLTWH(0, 780, 315, 305),
    ui.Rect.fromLTWH(330, 785, 400, 260),
    ui.Rect.fromLTWH(745, 750, 350, 335),
    ui.Rect.fromLTWH(1100, 795, 345, 290),
  ];

  ui.Rect actorFrame(int row, int column) {
    final w = actors.width / 8, h = actors.height / 7;
    return ui.Rect.fromLTWH(column * w + 1, row * h + 1, w - 2, h - 2);
  }

  void dispose() {
    lighting.dispose();
    groundShader.dispose();
    ground.dispose();
    props.dispose();
    actors.dispose();
    stances.dispose();
    architecture.dispose();
    details.dispose();
  }
}

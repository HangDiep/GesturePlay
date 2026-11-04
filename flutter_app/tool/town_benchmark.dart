// Run separately from the game: flutter run -d windows --profile
// -t tool/town_benchmark.dart. It closes itself after measuring ten seconds.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/exploration/world.dart';
import 'package:gestureplay/survival/art.dart';
import 'package:gestureplay/survival/painter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final art = await TownArt.load();
  runApp(_Benchmark(art));
}

class _Benchmark extends StatefulWidget {
  const _Benchmark(this.art);
  final TownArt art;
  @override
  State<_Benchmark> createState() => _BenchmarkState();
}

class _BenchmarkState extends State<_Benchmark>
    with SingleTickerProviderStateMixin {
  final model = ExplorationModel(FieldMap.town, survival: true)
    ..start()
    ..wave = 5;
  final samples = <FrameTiming>[];
  late final Ticker ticker;
  Duration previous = Duration.zero;
  int frames = 0;
  bool measuring = false;
  Size logicalSize = Size.zero;
  double pixelRatio = 1;
  Timer? warmup, finish;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(timings);
    ticker = createTicker(tick)..start();
    warmup = Timer(const Duration(seconds: 3), () {
      measuring = true;
      finish = Timer(const Duration(seconds: 10), complete);
    });
  }

  void timings(List<FrameTiming> timings) {
    if (measuring) samples.addAll(timings);
  }

  void tick(Duration time) {
    final dt = ((time - previous).inMicroseconds / 1e6).clamp(0.0, .1);
    previous = time;
    model.health = 100;
    model.reserve = 180;
    model.movement = TownView.movement(
      Offset(
        math.sin(time.inMilliseconds / 850),
        math.cos(time.inMilliseconds / 1300),
      ),
    );
    model.aim = model.player + const Offset(100, -150);
    model.firing = true;
    if (model.ammo == 0) model.reload();
    // Keep nine live creatures, with actual AI and pathfinding in the run.
    while (model.enemies.where((e) => e.alive).length < 9) {
      final e = model.spawn(CreatureKind.values[model.enemies.length % 4]);
      e.spawnFor = 0;
      if (const bool.fromEnvironment('TOWN_BENCHMARK_PHASE_TWO') &&
          e.kind == CreatureKind.boss) {
        model.hit(e, 450);
      }
    }
    model.update(dt);
    if (measuring) frames++;
    setState(() {});
  }

  void complete() {
    measuring = false;
    ticker.stop();
    double percentile(List<double> values, double p) {
      if (values.isEmpty) return -1;
      values.sort();
      return (values[((values.length - 1) * p).round()] * 100).round() / 100;
    }

    final report = {
      'platform': Platform.operatingSystem,
      'mode': 'profile',
      'render_layer': const String.fromEnvironment(
        'TOWN_BENCHMARK_LAYER',
        defaultValue: 'full',
      ),
      'duration_seconds': 10,
      'ticker_frames': frames,
      'ticker_fps': frames / 10,
      'timing_samples': samples.length,
      'build_p95_ms': percentile(
        samples.map((t) => t.buildDuration.inMicroseconds / 1000).toList(),
        .95,
      ),
      'raster_p95_ms': percentile(
        samples.map((t) => t.rasterDuration.inMicroseconds / 1000).toList(),
        .95,
      ),
      'live_enemies': model.enemies.where((e) => e.alive).length,
      'phase_two_bosses': model.enemies
          .where((e) => e.alive && e.enraged)
          .length,
      'ground_zones': model.bossRifts.length,
      'webcam': false,
      'logical_view':
          '${logicalSize.width.toInt()}x${logicalSize.height.toInt()}',
      'device_pixel_ratio': pixelRatio,
      'notes':
          'Native profile run with 9 AI enemies including ranged magic, gun effects, rain, fog, lanterns and camera movement. Excludes webcam recognition and browser overhead.',
    };
    const out = String.fromEnvironment(
      'TOWN_BENCHMARK_OUT',
      defaultValue: '../.cache/town-render-benchmark.json',
    );
    File(out)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      );
    // stdout is the machine-readable result for the standalone tool.
    // ignore: avoid_print
    print('TOWN_BENCHMARK ${jsonEncode(report)}');
    SchedulerBinding.instance.removeTimingsCallback(timings);
    exit(samples.isEmpty ? 1 : 0);
  }

  @override
  void dispose() {
    warmup?.cancel();
    finish?.cancel();
    ticker.dispose();
    SchedulerBinding.instance.removeTimingsCallback(timings);
    widget.art.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          logicalSize = constraints.biggest;
          pixelRatio = View.of(context).devicePixelRatio;
          const layer = String.fromEnvironment(
            'TOWN_BENCHMARK_LAYER',
            defaultValue: 'full',
          );
          return CustomPaint(
            size: logicalSize,
            painter: layer == 'full'
                ? TownPainter(model, widget.art)
                : _LayerProbe(model, widget.art, layer),
          );
        },
      ),
    ),
  );
}

class _LayerProbe extends CustomPainter {
  _LayerProbe(this.model, this.art, this.layer);
  final ExplorationModel model;
  final TownArt art;
  final String layer;
  @override
  void paint(Canvas c, Size size) {
    c.drawColor(const Color(0xff10202b), BlendMode.src);
    final view = TownView(model.player, size, world: model.world);
    c.save();
    c.scale(view.zoom);
    c.translate(-view.origin.dx, -view.origin.dy);
    if (layer == 'ground') {
      c.transform(TownView.matrix);
      c.drawRect(view.bounds, Paint()..shader = art.groundShader);
    } else if (layer == 'sprites') {
      for (final p in model.world.props.where(
        (p) => view.bounds.inflate(400).overlaps(p.rect),
      )) {
        final foot = TownView.floor(p.rect.center);
        c.drawImageRect(
          art.architecture,
          art.architectureFrames[0],
          Rect.fromLTWH(foot.dx - 190, foot.dy - 350, 380, 350),
          Paint()..filterQuality = FilterQuality.low,
        );
      }
    } else {
      c.drawCircle(
        TownView.floor(model.player),
        20,
        Paint()
          ..color = Color.lerp(Colors.white, Colors.blue, model.elapsed % 1)!,
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _LayerProbe oldDelegate) => true;
}

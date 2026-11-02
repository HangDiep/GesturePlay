import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'settings.dart';

class SignalAudio {
  SignalAudio(this.settings, {this.enabled = true});
  final SignalSettings settings;
  final bool enabled;
  AudioPlayer? _musicPlayer, _effectsPlayer;
  AudioPlayer get _music => _musicPlayer ??= AudioPlayer();
  AudioPlayer get _effects => _effectsPlayer ??= AudioPlayer();
  bool _playing = false;
  Future<void> sync({required bool playing}) async {
    if (!enabled) return;
    try {
      await _music.setVolume(settings.muted ? 0 : settings.music);
      if (playing && !_playing) {
        _playing = true;
        await _music.setReleaseMode(ReleaseMode.loop);
        await _music.play(AssetSource('audio/ambient.wav'));
      } else if (!playing && _playing) {
        _playing = false;
        await _music.stop();
      }
    } on Object {
      _playing = false;
    }
  }

  void play(String name) {
    if (!enabled || settings.muted || settings.effects <= 0) return;
    unawaited(_effect(name));
  }

  Future<void> _effect(String name) async {
    try {
      await _effects.setVolume(settings.effects);
      await _effects.play(AssetSource('audio/$name.wav'));
    } on Object {
      /* Audio failure must not interrupt a round. */
    }
  }

  void dispose() {
    if (!enabled) return;
    unawaited(_musicPlayer?.dispose());
    unawaited(_effectsPlayer?.dispose());
  }
}

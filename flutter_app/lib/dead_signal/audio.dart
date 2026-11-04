import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'settings.dart';

class SignalAudio {
  SignalAudio(this.settings, {this.enabled = true});
  final SignalSettings settings;
  final bool enabled;
  AudioPlayer? _musicPlayer, _effectsPlayer, _howlPlayer, _heartbeatPlayer;
  AudioPlayer? _magicPlayer;
  AudioPlayer get _music => _musicPlayer ??= AudioPlayer();
  AudioPlayer get _effects => _effectsPlayer ??= AudioPlayer();
  bool _playing = false;
  bool _wantedPlaying = false;
  bool _heartbeatPlaying = false;
  double _tensionVolume = -1;
  int _tensionEpoch = 0;
  Future<void> sync({required bool playing}) async {
    _wantedPlaying = playing;
    if (!enabled) return;
    if (!playing) {
      _playing = false;
      try {
        await _musicPlayer?.stop();
      } on Object {
        /* Stop tension even if music failed. */
      }
      await silenceTension();
      return;
    }
    try {
      await _music.setVolume(settings.muted ? 0 : settings.music);
      if (!_wantedPlaying) return;
      if (playing && !_playing) {
        _playing = true;
        await _music.setReleaseMode(ReleaseMode.loop);
        if (!_wantedPlaying) return;
        await _music.play(AssetSource('audio/ambient.wav'));
      }
    } on Object {
      _playing = false;
    }
  }

  /// A separate channel keeps approaching-creature howls audible under gunfire.
  void howl(double gain) {
    if (!enabled ||
        !_wantedPlaying ||
        settings.muted ||
        settings.effects <= 0) {
      return;
    }
    final epoch = _tensionEpoch;
    unawaited(() async {
      try {
        final player = _howlPlayer ??= AudioPlayer();
        await player.setVolume(settings.effects * gain.clamp(.2, 1));
        if (!_wantedPlaying || epoch != _tensionEpoch || settings.muted) return;
        await player.play(AssetSource('audio/creature_howl.wav'));
      } on Object {
        /* Visual threat cues remain available. */
      }
    }());
  }

  /// Casting remains audible under gunfire and uses the same pause epoch as
  /// other threat audio, so a late async load cannot start after leaving play.
  void magic(String name) {
    if (!enabled ||
        !_wantedPlaying ||
        settings.muted ||
        settings.effects <= 0) {
      return;
    }
    final epoch = _tensionEpoch;
    unawaited(() async {
      try {
        final player = _magicPlayer ??= AudioPlayer();
        await player.setVolume(settings.effects * .8);
        if (!_wantedPlaying || settings.muted || epoch != _tensionEpoch) return;
        await player.play(AssetSource('audio/$name.wav'));
      } on Object {
        /* Visual casting and projectile cues remain available. */
      }
    }());
  }

  Future<void> tension({required bool playing, required bool critical}) async {
    if (!enabled) return;
    final volume = playing && critical && !settings.muted
        ? settings.effects * .5
        : 0.0;
    if (_tensionVolume == volume) return;
    _tensionVolume = volume;
    final epoch = _tensionEpoch;
    try {
      if (volume == 0) {
        _heartbeatPlaying = false;
        await _heartbeatPlayer?.stop();
      } else {
        final player = _heartbeatPlayer ??= AudioPlayer();
        await player.setVolume(volume);
        if (_tensionVolume == 0 || !_wantedPlaying || epoch != _tensionEpoch) {
          return;
        }
        if (!_heartbeatPlaying) {
          _heartbeatPlaying = true;
          await player.setReleaseMode(ReleaseMode.loop);
          if (_tensionVolume == 0 ||
              !_wantedPlaying ||
              epoch != _tensionEpoch) {
            return;
          }
          await player.play(AssetSource('audio/heartbeat.wav'));
        }
      }
    } on Object {
      _heartbeatPlaying = false;
    }
  }

  Future<void> silenceTension() async {
    if (!enabled) return;
    _tensionEpoch++;
    _tensionVolume = 0;
    _heartbeatPlaying = false;
    try {
      await _howlPlayer?.stop();
      await _heartbeatPlayer?.stop();
      await _magicPlayer?.stop();
    } on Object {
      /* Never block pausing because of audio. */
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
    unawaited(_howlPlayer?.dispose());
    unawaited(_heartbeatPlayer?.dispose());
    unawaited(_magicPlayer?.dispose());
  }
}

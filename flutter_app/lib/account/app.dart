import 'dart:async';
import 'package:flutter/material.dart';
import '../dead_signal/settings.dart';
import '../services/hand_bridge.dart';
import '../survival/app.dart';
import '../survival/art.dart';
import '../survival/round_result.dart';
import 'auth_screen.dart';
import 'connection_page.dart';
import 'models.dart';
import 'player_pages.dart';
import 'result_journal.dart';
import 'result_widgets.dart';
import 'ui.dart';

class GesturePlayApp extends StatelessWidget {
  const GesturePlayApp({
    super.key,
    this.gateway = const PendingAccountGateway(),
    this.bridge,
    this.art,
    this.audioEnabled = true,
  });
  final AccountGateway gateway;
  final HandBridge? bridge;
  final TownArt? art;
  final bool audioEnabled;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GesturePlay — DEAD SIGNAL',
    debugShowCheckedModeBanner: false,
    theme: portalTheme(),
    home: _AccountGate(
      gateway: gateway,
      bridge: bridge,
      art: art,
      audioEnabled: audioEnabled,
    ),
  );
}

class _AccountGate extends StatefulWidget {
  const _AccountGate({
    required this.gateway,
    this.bridge,
    this.art,
    required this.audioEnabled,
  });
  final AccountGateway gateway;
  final HandBridge? bridge;
  final TownArt? art;
  final bool audioEnabled;
  @override
  State<_AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<_AccountGate> {
  late final hand = widget.bridge ?? HandBridge();
  PlayerProfile? _player;
  SignalSettings? _settings;
  TownArt? _art;
  ResultJournal? _journal;
  @override
  void initState() {
    super.initState();
    _art = widget.art;
  }

  @override
  void dispose() {
    hand.stop();
    _journal?.dispose();
    if (widget.bridge == null) hand.dispose();
    if (widget.art == null) _art?.dispose();
    super.dispose();
  }

  Future<void> _enter(PlayerProfile profile) async {
    final settings = SignalSettings(storageKey: 'player.${profile.id}.signal');
    await settings.load();
    final art = _art ?? await TownArt.load();
    if (!mounted) {
      if (_art == null && widget.art == null) art.dispose();
      return;
    }
    _art = art;
    final journal = ResultJournal(
      playerId: profile.id,
      preview: profile.preview,
      gateway: widget.gateway,
    );
    await journal.load();
    if (!mounted) {
      journal.dispose();
      return;
    }
    _journal?.dispose();
    setState(() {
      _art = art;
      _player = profile;
      _settings = settings;
      _journal = journal;
    });
  }

  Future<void> _page(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    hand.stop();
    if (_player?.preview != true) await widget.gateway.signOut();
    if (!mounted) return;
    _journal?.dispose();
    setState(() {
      _player = null;
      _settings = null;
      _journal = null;
    });
  }

  Future<PlayerProfile> _rename(String name) async {
    final player = _player!;
    final updated = player.preview
        ? player.renamed(name)
        : await widget.gateway.rename(name);
    if (mounted && _player?.id == player.id) setState(() => _player = updated);
    return updated;
  }

  void _result(RoundResult result) {
    final journal = _journal;
    if (journal != null) unawaited(journal.add(result));
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player == null) {
      return AuthScreen(
        gateway: widget.gateway,
        onAuthenticated: _enter,
        onPreview: () => _enter(
          const PlayerProfile(
            id: 'preview',
            displayName: 'Người giữ tín hiệu',
            preview: true,
          ),
        ),
      );
    }
    return SurvivalApp(
      audioEnabled: widget.audioEnabled,
      bridge: hand,
      settings: _settings,
      art: _art,
      stopBridgeOnDispose: false,
      playerName: player.displayName,
      previewAccount: player.preview,
      results: _journal,
      onResultDetails: (result) =>
          _page(RoundDetailPage(result: result, journal: _journal)),
      onProfile: () => _page(
        ProfilePage(
          profile: player,
          records: _journal!.records,
          journal: _journal,
          onRename: _rename,
        ),
      ),
      onHistory: () => _page(
        HistoryPage(
          records: _journal!.records,
          preview: player.preview,
          journal: _journal,
        ),
      ),
      onConnection: () =>
          _page(ConnectionPage(hand: hand, settings: _settings!)),
      onPractice: () => _page(
        SurvivalApp(
          audioEnabled: widget.audioEnabled,
          bridge: hand,
          settings: _settings,
          art: _art,
          practice: true,
          stopBridgeOnDispose: false,
        ),
      ),
      onLogout: _logout,
      onResult: _result,
    );
  }
}

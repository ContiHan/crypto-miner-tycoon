import 'dart:math';

import '../../core/constants.dart';
import '../../services/casino_service.dart';

/// Owns the SWEEP economy: the per-real-time-window net-gain anti-farm cap and
/// the resolve/commit split for slots / hash-flip / plinko. Wraps the pure
/// [CasinoService] (odds/EV live there).
///
/// `chips` (the persisted UTXO) is NOT owned here — the crate shop spends it too
/// — so this manager reads/mutates it through the [chips]/[setChips] seam.
/// Luck, wall-clock feedback (sound/haptics), achievement evaluation, save and
/// notify are all injected by GameLogic, keeping this free of Provider/UI/audio
/// concerns. The counters [spins]/[jackpots] and the window fields
/// [windowNet]/[windowStartMs] are persisted (GameLogic serializes them via the
/// [reset]/[restore] seam).
class CasinoManager {
  CasinoManager({
    required this.rng,
    required this.chips,
    required this.setChips,
    required this.sweepLuck,
    required this.onWinSound,
    required this.onWinHaptic,
    required this.onJackpotHaptic,
    required this.evaluateAchievements,
    required this.save,
    required this.notify,
  });

  /// Injectable so tests can force deterministic spins.
  final Random rng;

  /// The shared UTXO balance (lives in GameLogic).
  final int Function() chips;
  final void Function(int value) setChips;

  /// WHALE'S FAVOR luck applied to SWEEP payouts (bounded by the EV ceiling).
  final double Function() sweepLuck;

  /// Reveal feedback (skipped on a silent commit — see [commit]).
  final void Function() onWinSound;
  final void Function() onWinHaptic;
  final void Function() onJackpotHaptic;

  final void Function() evaluateAchievements;
  final void Function() save;
  final void Function() notify;

  final CasinoService _casino = CasinoService();

  // --- persisted state ---
  int spins = 0;
  int jackpots = 0;

  // --- Anti-farm: the NET UTXO gained from SWEEP per real-time window is capped;
  // past it, sweeps are blocked until the window resets ("mempool congested"). --
  double windowNet = 0; // net UTXO gained since the window opened
  int windowStartMs = 0; // window-open epoch ms (0 = not yet opened)

  static const int _windowMs =
      GameConstants.casinoWindowHours * 60 * 60 * 1000;

  bool _windowExpired(int nowMs) =>
      windowStartMs == 0 || nowMs - windowStartMs >= _windowMs;

  /// Net UTXO gained in the CURRENT window (0 once it has elapsed). Pure read.
  double get netThisWindow =>
      _windowExpired(DateTime.now().millisecondsSinceEpoch) ? 0 : windowNet;

  /// True when the per-window net-gain cap is reached — sweeps are blocked until
  /// the window resets. Pure read (no mutation), safe to call during build.
  bool get capped => netThisWindow >= GameConstants.casinoDailyNetCap;

  /// Milliseconds until the current window resets (0 if none open / already up).
  int get windowResetInMs {
    if (windowStartMs == 0) return 0;
    final left =
        _windowMs - (DateTime.now().millisecondsSinceEpoch - windowStartMs);
    return left < 0 ? 0 : left;
  }

  /// Opens a fresh window (resetting the net) if none is open or the current one
  /// has elapsed, then reports whether a sweep is allowed (block threshold not
  /// yet reached). The crossing sweep is still paid in full — see [casinoDailyNetCap].
  bool _beginSweep() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_windowExpired(now)) {
      windowStartMs = now;
      windowNet = 0;
    }
    return windowNet < GameConstants.casinoDailyNetCap;
  }

  // --- SWEEP: resolve/commit split -----------------------------------------
  // Each game splits into RESOLVE (gate on the cap + deduct the stake + roll the
  // RNG outcome) and COMMIT (credit the payout, advance the net cap, count the
  // spin, play feedback, evaluate achievements, notify + save). The animated UI
  // resolves at the tap so the reels/ball/nonce show the REAL outcome, then calls
  // commit only once the animation lands — otherwise a win, an achievement
  // toast, or the "MEMPOOL CONGESTED" cap would flash at tap time, before the
  // animation finishes. The one-shot play* wrappers (resolve+commit) stay for
  // tests and any non-animated path.

  /// Bet [bet] UTXO on the slots (one-shot). Null if unaffordable or capped.
  SlotSpin? playSlots(int bet) {
    final spin = resolveSlots(bet);
    if (spin != null) commit(spin);
    return spin;
  }

  /// Deduct the stake and roll a slots spin WITHOUT committing it (see [commit]).
  /// Null if unaffordable or the per-window cap blocks play.
  SlotSpin? resolveSlots(int bet) {
    if (bet <= 0 || chips() < bet) return null;
    if (!_beginSweep()) return null;
    setChips(chips() - bet);
    return _casino.spinSlots(bet, rng, luck: sweepLuck());
  }

  /// Hash Flip on [bet] UTXO — the high-variance game (mostly busts, rare 30×
  /// jackpot), one-shot. Null if unaffordable or capped.
  FlipResult? playDoubleOrNothing(int bet) {
    final result = resolveFlip(bet);
    if (result != null) commit(result);
    return result;
  }

  /// Deduct the stake and roll a Hash Flip WITHOUT committing it (see [commit]).
  /// Null if unaffordable or the per-window cap blocks play.
  FlipResult? resolveFlip(int bet) {
    if (bet <= 0 || chips() < bet) return null;
    if (!_beginSweep()) return null;
    setChips(chips() - bet);
    return _casino.flip(bet, rng, luck: sweepLuck());
  }

  /// Relay a packet for [bet] UTXO (one-shot). Null if unaffordable or capped.
  PlinkoDrop? playPlinko(int bet) {
    final drop = resolvePlinko(bet);
    if (drop != null) commit(drop);
    return drop;
  }

  /// Deduct the stake and roll a relay drop WITHOUT committing it (see [commit]).
  /// Null if unaffordable or the per-window cap blocks play.
  PlinkoDrop? resolvePlinko(int bet) {
    if (bet <= 0 || chips() < bet) return null;
    if (!_beginSweep()) return null;
    setChips(chips() - bet);
    return _casino.dropPlinko(bet, rng, luck: sweepLuck());
  }

  /// Commit a RESOLVED sweep outcome (the stake was already deducted by the
  /// matching resolve*): credit the payout, advance the per-window net (which can
  /// trip the cap), count the spin/jackpot, evaluate achievements, and always
  /// SAVE (so a background/kill can't lose the staked UTXO).
  ///
  /// When [silent] (the animation never got to land — the screen is being
  /// disposed or the app is backgrounding), skip the reveal feedback: no sound,
  /// no haptic, and NO notify — the latter would call markNeedsBuild during the
  /// framework's locked teardown and assert in debug. The currency is still
  /// committed exactly once and persisted; the UI reflects it on its next natural
  /// rebuild.
  void commit(SweepOutcome outcome, {bool silent = false}) {
    setChips(chips() + outcome.payout);
    windowNet += outcome.net;
    spins++;
    if (outcome.isJackpot) jackpots++;
    if (!silent) {
      if (outcome.isWin) onWinSound(); // win chime (a bust is silent)
      if (outcome.isJackpot) {
        onJackpotHaptic();
      } else if (outcome.isWin) {
        onWinHaptic();
      }
    }
    // On a SILENT commit (teardown/backgrounding) skip achievement evaluation so
    // its cue can't fire during teardown — the counters are saved below, so any
    // crossed achievement unlocks on the next natural evaluation (or on reload).
    if (!silent) evaluateAchievements();
    if (!silent) notify();
    save();
  }

  /// Clear all SWEEP state (full reset / wipe).
  void reset() {
    spins = 0;
    jackpots = 0;
    windowNet = 0;
    windowStartMs = 0;
  }

  /// Restore persisted SWEEP state on load.
  void restore({
    required int spins,
    required int jackpots,
    required double windowNet,
    required int windowStartMs,
  }) {
    this.spins = spins;
    this.jackpots = jackpots;
    this.windowNet = windowNet;
    this.windowStartMs = windowStartMs;
  }
}

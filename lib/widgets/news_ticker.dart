import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/game_logic.dart';
import '../models/news_event.dart';
import '../content/news_flavor.dart';
import '../utils/formatter.dart';

class NewsTicker extends StatelessWidget {
  const NewsTicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameLogic>(
      builder: (context, game, child) {
        final NewsEvent? news = game.currentNews;

        // Determine Content
        String text;
        Color color;
        Color bgColor;
        Key key; // Key for AnimatedSwitcher

        if (news != null) {
          text = "BREAKING: ${news.message}";

          String impact = "";
          switch (news.type) {
            case EventType.marketCrash:
              impact = "${news.value}% Income";
              break;
            case EventType.bullRun:
              impact = "+${news.value}% Income";
              break;
            case EventType.hack:
              impact = "Lost ${Formatter.formatBitcoin(news.value.abs())}";
              break;
            case EventType.cheapEnergy:
              impact = "${news.value}% Rig Cost";
              break;
            case EventType.info:
              if (news.value != 0) impact = "Reward ${news.value}%";
              break;
          }

          if (impact.isNotEmpty) {
            text += "   ///   IMPACT: $impact";
          }

          color = news.color;
          bgColor = news.color.withValues(alpha: 0.2);
          key = ValueKey('news_${news.hashCode}');
        } else {
          // Idle State: a rotating window of funny crypto headlines interleaved
          // with live stats. The window advances every ~45s (fades via the key).
          final flavors = NewsFlavor.idle;
          final bucket = DateTime.now().millisecondsSinceEpoch ~/ 45000;
          final start = bucket % flavors.length;
          final window = [
            for (int i = 0; i < 6; i++) flavors[(start + i) % flavors.length],
          ].join('   ///   ');
          text =
              "$window   ///   NETWORK DIFFICULTY: ${Formatter.formatNumber(game.networkDifficulty)}   ///   BLOCK REWARD: ${Formatter.formatBitcoin(game.blockReward)}   ///   ";
          color = Colors.white54;
          bgColor = Colors.black45;
          key = ValueKey('idle_$bucket');
        }

        // Define Style with Glow. Use the app's bundled Orbitron (the "LED"
        // brand font) — GoogleFonts.dotGothic16 required a runtime fetch which
        // is disabled in release (allowRuntimeFetching=false), so it fell back
        // to the plain system font and the ticker looked off-brand.
        final textStyle = GoogleFonts.orbitron(
          color: color,
          fontSize: 13,
          letterSpacing: 1.0, // spaced-out glyphs read as an LED strip
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: color.withValues(alpha: 0.6), // Was 0.8
              blurRadius: 4, // Was 8
            ),
            Shadow(
              color: color.withValues(alpha: 0.2), // Was 0.4
              blurRadius: 8, // Was 15
            ),
          ],
        );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: double.infinity,
          height: 36, // Increased height for font/glow
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(color: color.withValues(alpha: 0.5), width: 1),
            ),
          ),
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _ScrollingText(
                key: key,
                text: text,
                style: textStyle,
                speed: news != null ? 80.0 : 40.0,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double speed;

  const _ScrollingText({
    super.key,
    required this.text,
    required this.style,
    this.speed = 30.0,
  });

  @override
  State<_ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<_ScrollingText>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _offset = 0.0;
  double _textWidth = 0.0;
  double _widgetWidth = 0.0;

  Duration _lastTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    if (!mounted) return;

    double dt = (elapsed - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = elapsed;

    if (dt > 0.1) dt = 0.016;

    setState(() {
      _offset -= widget.speed * dt;

      if (_offset < -_textWidth) {
        _offset = _widgetWidth;
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _widgetWidth = constraints.maxWidth;

        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        _textWidth = textPainter.width;

        if (_offset == 0.0 && _lastTime == Duration.zero) {
          _offset = _widgetWidth;
        }

        return Stack(
          children: [
            Positioned(
              left: _offset,
              top: (constraints.maxHeight - textPainter.height) / 2,
              child: Text(widget.text, style: widget.style),
            ),
          ],
        );
      },
    );
  }
}

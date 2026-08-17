import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crypto_miner_tycoon/widgets/cyber_toast.dart';

/// The top-anchored cyberpunk toast (owner: "all toasts at the top with a
/// cyberpunk effect"). These guard against runtime breakage (overlay insert,
/// entrance animation, ClipPath, the FIFO queue) since it can't be eyeballed here.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget host() => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => showCyberToast(context,
                        message: 'First Unlock',
                        duration: const Duration(milliseconds: 500)),
                    child: const Text('a'),
                  ),
                  ElevatedButton(
                    onPressed: () => showCyberToast(context,
                        message: 'Second Unlock',
                        duration: const Duration(milliseconds: 500)),
                    child: const Text('b'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('appears at the top (uppercased) then auto-dismisses',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('a'));
    await tester.pump(); // insert the overlay entry
    await tester.pump(const Duration(milliseconds: 400)); // entrance settles

    expect(find.text('FIRST UNLOCK'), findsOneWidget);
    // Anchored near the top of the screen, not the bottom.
    final y = tester.getTopLeft(find.text('FIRST UNLOCK')).dy;
    expect(y, lessThan(200));

    await tester.pump(const Duration(milliseconds: 200)); // fire the hold timer
    await tester.pump(const Duration(milliseconds: 400)); // exit animation
    expect(find.text('FIRST UNLOCK'), findsNothing);
  });

  testWidgets('queues: the second toast shows only after the first finishes',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('a'));
    await tester.pump();
    await tester.tap(find.text('b'));
    await tester.pump(const Duration(milliseconds: 400));

    // Only the first is up while it holds.
    expect(find.text('FIRST UNLOCK'), findsOneWidget);
    expect(find.text('SECOND UNLOCK'), findsNothing);

    // Let the first hold + exit, then the queued second appears.
    await tester.pump(const Duration(milliseconds: 200)); // first hold fires
    await tester.pump(const Duration(milliseconds: 400)); // first exits → second in
    await tester.pump(const Duration(milliseconds: 400)); // second entrance
    expect(find.text('SECOND UNLOCK'), findsOneWidget);

    // Drain the second so no timers leak past the test.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SECOND UNLOCK'), findsNothing);
  });
}

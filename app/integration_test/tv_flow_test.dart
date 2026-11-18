// Parcours TV sur la box (non exécutable hors appareil) :
//   flutter test integration_test/tv_flow_test.dart -d 192.168.0.43:5555
//
// Même scénario que test/tv_flow_test.dart, mais avec l'écran et la détection
// TV réels de l'appareil : application complète, addon factice (aucun réseau),
// accueil -> fiche -> lecture en 2 événements Select.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accueil -> fiche -> lecture en <= 4 événements', (t) async {
    // resizeView: false : on garde la résolution réelle de la box.
    final h = AppHarness(t, resizeView: false);
    await h.pumpApp();
    var events = 0;

    // 1. Select sur la première carte (focus d'emblée) : ouvre la fiche.
    await t.sendKeyEvent(LogicalKeyboardKey.select);
    events++;
    await h.settle();
    expect(find.text('Un court métrage libre de droits.'), findsOneWidget);

    // 2. Select sur « Lecture auto » (focus d'emblée) : lance la lecture.
    await t.sendKeyEvent(LogicalKeyboardKey.select);
    events++;
    await h.settle();

    expect(h.players, hasLength(1));
    expect(events, lessThanOrEqualTo(4));
    await h.close();
  });
}

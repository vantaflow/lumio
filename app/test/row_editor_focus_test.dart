import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/home/row_editor_screen.dart';

import 'support/app_harness.dart';

void main() {
  testWidgets('Personnaliser : un élément a le focus à l\'ouverture', (
    t,
  ) async {
    final h = AppHarness(t);
    await h.pump(const RowEditorScreen());
    expect(find.byKey(const ValueKey('focus-ring')), findsWidgets);
    await h.close();
  });
}

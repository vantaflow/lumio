import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/library/library_screen.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/app_harness.dart';

void main() {
  testWidgets('Ma liste : la première carte a le focus à l\'ouverture', (
    t,
  ) async {
    final h = AppHarness(t);
    await h.pump(
      const LibraryScreen(),
      extra: [
        libraryProvider.overrideWith(
          (ref) => Stream.value([
            for (final n in ['A', 'B'])
              MetaPreview(id: n, type: 'movie', name: n, sourceAddonId: 'a'),
          ]),
        ),
      ],
    );
    expect(find.byType(FocusableCard), findsWidgets);
    expect(find.byKey(const ValueKey('focus-ring')), findsOneWidget);
    await h.close();
  });
}

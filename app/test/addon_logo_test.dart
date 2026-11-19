import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/addons/addon_logo.dart';
import 'package:lumio/ui/common/guarded_image.dart';
import 'package:lumio/ui/theme.dart';

Widget _wrap(Uri? logo) => MaterialApp(
  theme: LumioTheme.dark(),
  home: Scaffold(body: AddonLogo(logo: logo)),
);

void main() {
  testWidgets('le logo passe par GuardedNetworkImage (pas Image.network)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(Uri.parse('https://cdn.example.com/l.png')));
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.image, isA<GuardedNetworkImage>());
    expect((img.image as GuardedNetworkImage).allowPrivate, isFalse);
  });

  testWidgets('logo privé : icône de repli, aucune image', (tester) async {
    await tester.pumpWidget(_wrap(Uri.parse('http://192.168.1.2/l.png')));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.extension_outlined), findsOneWidget);
  });
}

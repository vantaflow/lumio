import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fonctionnalité système qui identifie un appareil Android TV.
const leanbackFeature = 'android.software.leanback';

/// Vrai sur un Android TV (fonctionnalité `leanback`). Hors Android, ou si la
/// lecture échoue, renvoie faux. [isAndroid] et [features] servent aux tests.
Future<bool> detectAndroidTv({
  bool? isAndroid,
  Future<List<String>> Function()? features,
}) async {
  try {
    if (!(isAndroid ?? Platform.isAndroid)) return false;
    final list =
        await (features ??
            () async =>
                (await DeviceInfoPlugin().androidInfo).systemFeatures)();
    return list.contains(leanbackFeature);
  } catch (_) {
    return false;
  }
}

/// Résultat de [detectAndroidTv], mis en cache au démarrage (`main` surcharge
/// ce fournisseur) ; faux par défaut (tests, ordinateur).
final androidTvProvider = Provider<bool>((ref) => false);

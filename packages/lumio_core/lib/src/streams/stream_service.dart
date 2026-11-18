import 'dart:async';

import '../addons/addon_client.dart';
import '../addons/manifest.dart';
import 'stream_item.dart';
import 'stream_normalizer.dart';

/// Interroge en parallèle les addons compatibles et émet un [StreamGroup] par
/// addon, dans l'ordre d'arrivée. Un addon en échec donne un groupe avec
/// `error` ; le flux Dart lui-même n'émet jamais d'erreur.
class StreamService {
  StreamService(this._client, {this.onLog});

  final AddonClient _client;

  /// Journal facultatif ; les messages ne contiennent jamais d'URL en clair.
  final void Function(String message)? onLog;

  Stream<StreamGroup> load(List<AddonManifest> addons, String type, String id) {
    final targets = addons
        .where((a) => a.supports('stream', type, id))
        .toList();
    final controller = StreamController<StreamGroup>();
    var pending = targets.length;
    if (pending == 0) {
      controller.close();
      return controller.stream;
    }
    for (final a in targets) {
      () async {
        StreamGroup group;
        try {
          final raws = await _client.rawStreams(a, type, id);
          final items = <StreamItem>[
            for (final r in raws)
              ?StreamNormalizer.normalize(r, a.id, onReject: onLog),
          ];
          group = StreamGroup(addonId: a.id, items: items);
        } catch (e) {
          group = StreamGroup(addonId: a.id, error: e);
        }
        if (!controller.isClosed) controller.add(group);
        if (--pending == 0) await controller.close();
      }();
    }
    return controller.stream;
  }
}

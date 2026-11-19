import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio/features/home/continue_playback.dart';
import 'package:lumio/features/settings/settings_providers.dart'
    show LocaleController, localeProvider;
import 'package:lumio_core/lumio_core.dart';

class _Launcher implements PlaybackLauncher {
  _Launcher(this.meta);
  final Meta? meta;
  int loads = 0;

  @override
  Future<Meta> loadMeta(MetaPreview p) async {
    loads++;
    final m = meta;
    if (m == null) throw StateError('aucun addon de métadonnées');
    return m;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Locale extends LocaleController {
  @override
  Locale build() => const Locale('fr');
}

ProgressEntry _entry({String? title, String? poster, int? s, int? e}) =>
    ProgressEntry(
      profileId: 'p',
      metaId: 'tt0458339',
      videoId: s == null ? 'tt0458339' : 'tt0458339:$s:$e',
      position: const Duration(minutes: 1),
      duration: const Duration(minutes: 90),
      watched: false,
      updatedAt: DateTime.utc(2026),
      title: title,
      poster: poster,
      season: s,
      episode: e,
    );

ProviderContainer _container(_Launcher l) {
  final c = ProviderContainer(
    overrides: [
      playbackLauncherProvider.overrideWithValue(l),
      activeAddonsProvider.overrideWithValue(const []),
      localeProvider.overrideWith(_Locale.new),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

final _playback = Provider<DefaultContinuePlayback>(
  DefaultContinuePlayback.new,
);

void main() {
  test('titre et affiche mémorisés : aucune requête meta', () async {
    final l = _Launcher(null);
    final c = _container(l);
    final info = await c
        .read(_playback)
        .describe(
          _entry(
            title: 'Captain America',
            poster: 'https://img.example/p.jpg',
            s: 1,
            e: 2,
          ),
        );
    expect(info.title, 'Captain America');
    expect(info.subtitle, 'S1E2');
    expect(info.poster.toString(), 'https://img.example/p.jpg');
    expect(l.loads, 0);
  });

  test('ancienne ligne : repli sur la requête meta', () async {
    final l = _Launcher(
      Meta(id: 'tt0458339', type: 'movie', name: 'Captain America'),
    );
    final c = _container(l);
    final info = await c.read(_playback).describe(_entry());
    expect(info.title, 'Captain America');
    expect(l.loads, 1);
  });

  test(
    'aucune source de titre : « Titre inconnu », jamais l\'identifiant',
    () async {
      final c = _container(_Launcher(null));
      final info = await c.read(_playback).describe(_entry());
      expect(info.title, 'Titre inconnu');
      expect(info.title, isNot(contains('tt0458339')));
    },
  );

  group('épisode affiché même sans saison/épisode mémorisés', () {
    ProgressEntry at0(String metaId, String videoId) => ProgressEntry(
      profileId: 'p',
      metaId: metaId,
      videoId: videoId,
      position: Duration.zero,
      duration: Duration.zero,
      watched: false,
      updatedAt: DateTime.utc(2026),
      title: 'Série',
    );

    test('série à 0 s : « SxEy » tiré de la vidéo', () async {
      final c = _container(_Launcher(null));
      final info = await c
          .read(_playback)
          .describe(at0('tt0458339', 'tt0458339:3:3'));
      expect(info.subtitle, 'S3E3');
    });

    test('anime (kitsu:id:épisode) à 0 s : « E5 »', () async {
      final c = _container(_Launcher(null));
      final info = await c
          .read(_playback)
          .describe(at0('kitsu:1', 'kitsu:1:5'));
      expect(info.subtitle, 'E5');
    });

    test('film : aucun libellé', () async {
      final c = _container(_Launcher(null));
      final info = await c
          .read(_playback)
          .describe(at0('tt0458339', 'tt0458339'));
      expect(info.subtitle, isNull);
    });
  });
}

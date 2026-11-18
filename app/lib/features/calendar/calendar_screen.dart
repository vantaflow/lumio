import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lumio/features/calendar/calendar_providers.dart';
import 'package:lumio/features/calendar/release_sync.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

const calendarRouteKey = 'calendar';

/// Entrées d'un même jour (heure locale) ; [day] est `null` pour le groupe
/// « date inconnue ».
class DayGroup {
  const DayGroup(this.day, this.entries);

  final DateTime? day;
  final List<CalendarEntry> entries;
}

/// Regroupe les entrées (déjà triées) par jour local ; le groupe « date
/// inconnue » reste en dernier.
List<DayGroup> groupByDay(List<CalendarEntry> entries) {
  final groups = <DayGroup>[];
  final unknown = <CalendarEntry>[];
  DateTime? current;
  for (final e in entries) {
    final d = e.date;
    if (d == null) {
      unknown.add(e);
      continue;
    }
    final u = d.toUtc();
    // Date sans heure (minuit UTC) : on garde le jour de la date, sans
    // glissement vers la veille à l'ouest de l'UTC.
    final dateOnly = u.hour == 0 && u.minute == 0 && u.second == 0;
    final l = dateOnly ? u : d.toLocal();
    final day = DateTime(l.year, l.month, l.day);
    if (current == null || day != current) {
      groups.add(DayGroup(day, []));
      current = day;
    }
    groups.last.entries.add(e);
  }
  if (unknown.isNotEmpty) groups.add(DayGroup(null, unknown));
  return groups;
}

/// « Aujourd'hui », « Demain », sinon jour de la semaine et date dans la
/// langue de l'interface.
String dayLabel(AppLocalizations l, Locale locale, DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (diff == 0) return l.calendarToday;
  if (diff == 1) return l.calendarTomorrow;
  try {
    return DateFormat.MMMMEEEEd(locale.toLanguageTag()).format(day);
  } on Object {
    return DateFormat.MMMMEEEEd().format(day);
  }
}

/// Libellé d'un épisode : « S1 · É2 » (et son titre s'il en a un).
String episodeLabel(AppLocalizations l, Video v) {
  final s = v.season;
  final e = v.episode;
  final base = e == null
      ? null
      : (s == null ? l.calendarEpisodeOnly(e) : l.calendarEpisodeLabel(s, e));
  final hasTitle = v.title != v.id && !v.title.startsWith('Épisode ');
  if (base == null) return v.title;
  return hasTitle ? '$base · ${v.title}' : base;
}

/// Calendrier des sorties (story 6.3) : prochains épisodes des séries de
/// « Ma liste », groupés par jour ; une série sans date est marquée « date
/// inconnue ». Un titre ouvre sa fiche.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.onOpenItem});

  final void Function(MetaPreview item)? onOpenItem;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  Future<void> _toggle(bool value) async {
    final ok = await ref.read(notifyReleasesProvider.notifier).set(value);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.calendarNotifyDenied)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = ref.watch(calendarProvider);
    final notify = ref.watch(notifyReleasesProvider).value ?? false;
    final syncFailed = ref.watch(releaseSyncErrorProvider);
    final memory = ref.read(focusMemoryProvider.notifier);
    final remembered = memory.restore(calendarRouteKey);

    final Widget body;
    if (data.hasError) {
      body = StateView.error(
        message: l.calendarLoadError,
        onRetry: () => ref.invalidate(calendarProvider),
      );
    } else if (!data.hasValue) {
      body = const StateView.loading();
    } else if (!data.requireValue.hasSeries) {
      body = StateView.empty(message: l.calendarEmpty);
    } else if (data.requireValue.entries.isEmpty) {
      body = StateView.empty(message: l.calendarNothingSoon);
    } else {
      body = _EntryList(
        data: data.requireValue,
        onOpenItem: widget.onOpenItem,
        remembered: remembered,
        onFocused: (id) => memory.remember(calendarRouteKey, id),
      );
    }

    return TvScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.calendarTitle),
          backgroundColor: Colors.transparent,
        ),
        body: Column(
          children: [
            FocusRing(
              child: SwitchListTile(
                key: const ValueKey('calendar-notify'),
                autofocus: remembered == null || remembered == 'notify',
                title: Text(l.calendarNotify),
                subtitle: syncFailed
                    ? Text(
                        l.calendarNotifyError,
                        key: const ValueKey('calendar-notify-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : Text(l.calendarNotifyHint),
                value: notify,
                onChanged: _toggle,
                onFocusChange: (f) {
                  if (f) memory.remember(calendarRouteKey, 'notify');
                },
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.data,
    required this.onOpenItem,
    required this.remembered,
    required this.onFocused,
  });

  final CalendarData data;
  final void Function(MetaPreview item)? onOpenItem;
  final String? remembered;
  final void Function(String id) onFocused;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context);
    final now = DateTime.now();
    final rows = <Widget>[];
    for (final g in groupByDay(data.entries)) {
      final day = g.day;
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LumioSpacing.xl,
            LumioSpacing.lg,
            LumioSpacing.xl,
            LumioSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(
              day == null
                  ? l.calendarUnknownHeader
                  : dayLabel(l, locale, day, now),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: context.lumio.accent),
            ),
          ),
        ),
      );
      for (final e in g.entries) {
        final id = 'e:${e.series.id}|${e.video?.id ?? ''}';
        final preview = data.previews[e.series.id];
        rows.add(
          FocusRing(
            child: ListTile(
              key: ValueKey(id),
              autofocus: remembered == id,
              title: Text(e.series.name),
              subtitle: Text(
                e.video == null
                    ? l.calendarUnknownEntry
                    : episodeLabel(l, e.video!),
              ),
              trailing: const Icon(Icons.chevron_right),
              onFocusChange: (f) {
                if (f) onFocused(id);
              },
              onTap: preview == null ? null : () => onOpenItem?.call(preview),
            ),
          ),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: LumioSpacing.xl),
      children: rows,
    );
  }
}

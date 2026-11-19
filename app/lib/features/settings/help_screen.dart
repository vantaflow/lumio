import 'package:flutter/material.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/common/tv_guide.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/common/tv_scroll_clip.dart';
import 'package:lumio/ui/theme.dart';

/// Un guide de la page « Aide » : titre, résumé (première étape) et étapes.
class HelpGuide {
  const HelpGuide(this.id, this.title, this.steps, {this.note});

  final String id;
  final String title;
  final List<String> steps;
  final String? note;
}

/// Les guides de l'aide (même contenu sur le portail du téléphone).
List<HelpGuide> helpGuides(AppLocalizations l) => [
  HelpGuide('addons', l.helpAddonsTitle, [
    l.helpAddonsStep1,
    l.helpAddonsStep2,
    l.helpAddonsStep3,
  ]),
  HelpGuide('setting', l.helpSettingTitle, [
    l.helpSettingStep1,
    l.helpSettingStep2,
    l.helpSettingStep3,
  ], note: l.guideNoteKeyStays),
  HelpGuide('portal', l.helpPortalTitle, [
    l.helpPortalStep1,
    l.helpPortalStep2,
    l.helpPortalStep3,
    l.helpPortalStep4,
  ]),
  HelpGuide('trakt', l.helpTraktTitle, [
    l.traktStep1,
    l.traktStep2,
    l.traktStep3,
    l.traktStep4,
  ]),
  HelpGuide('profiles', l.helpProfilesTitle, [
    l.helpProfilesStep1,
    l.helpProfilesStep2,
    l.helpProfilesStep3,
  ]),
  HelpGuide('subs', l.helpSubsTitle, [
    l.helpSubsStep1,
    l.helpSubsStep2,
    l.helpSubsStep3,
  ]),
];

/// Page « Aide » (Réglages › Général › Aide, maquette G04) : une carte par
/// sujet ; OK ouvre le guide pas à pas.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final guides = helpGuides(l);
    return TvScreen(
      title: l.settingsHelp,
      subtitle: l.settingsHelpHint,
      child: TvScrollClip(
        child: ListView(
          key: const ValueKey('help-list'),
          clipBehavior: Clip.none,
          padding: EdgeInsets.zero,
          children: [
            for (final (i, g) in guides.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TvFocusTile(
                  key: ValueKey('help:${g.id}'),
                  autofocus: i == 0,
                  minHeight: 128,
                  idleColor: c.surface,
                  semanticLabel: g.title,
                  onSelect: () => showTvGuide(
                    context,
                    title: g.title,
                    steps: g.steps,
                    note: g.note,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 18,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontSize: 36, height: 1.2),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            g.steps.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 26,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

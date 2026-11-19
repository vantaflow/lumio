import 'package:flutter/material.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/common/tv_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/features/addons/add_addon_screen.dart';
import 'package:lumio/features/jellyfin/jellyfin_screen.dart'
    show JellyfinAddDialog;
import 'package:lumio/features/local/local_screen.dart' show addLocalFolderFlow;
import 'package:lumio/features/onboarding/tv_onboarding.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/features/profiles/pin_dialog.dart';
import 'package:lumio/features/profiles/profile_picker_screen.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';

const onboardingRouteKey = 'onboarding';

/// État persistant de l'assistant : terminé ? passé ? rappel masqué ?
class OnboardingState {
  const OnboardingState({
    required this.done,
    this.skipped = false,
    this.reminderDismissed = false,
  });

  final bool done;
  final bool skipped;
  final bool reminderDismissed;

  bool get showReminder => done && skipped && !reminderDismissed;
}

final onboardingProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingController extends AsyncNotifier<OnboardingState> {
  AppSettingsStore get _store => ref.read(appSettingsStoreProvider);

  @override
  Future<OnboardingState> build() async {
    try {
      final done = await _store.read(AppSettingsStore.onboardingDoneKey);
      if (done == null) {
        // Installation existante (mise à jour) : des addons sont déjà là, pas
        // d'assistant.
        final addons = await ref.read(addonRepositoryProvider).list();
        if (addons.isNotEmpty) {
          await _store.write(AppSettingsStore.onboardingDoneKey, '1');
          return const OnboardingState(done: true);
        }
        return const OnboardingState(done: false);
      }
      return OnboardingState(
        done: true,
        skipped:
            await _store.read(AppSettingsStore.onboardingSkippedKey) == '1',
        reminderDismissed:
            await _store.read(AppSettingsStore.sourcesReminderDismissedKey) ==
            '1',
      );
    } on Object {
      // Réglage illisible : ne jamais bloquer l'application.
      return const OnboardingState(done: true);
    }
  }

  /// Termine l'assistant ; lève si l'écriture échoue (état inchangé).
  Future<void> finish({required bool skipped}) async {
    await _store.write(AppSettingsStore.onboardingDoneKey, '1');
    if (skipped) await _store.write(AppSettingsStore.onboardingSkippedKey, '1');
    state = AsyncData(OnboardingState(done: true, skipped: skipped));
  }

  Future<void> dismissReminder() async {
    await _store.write(AppSettingsStore.sourcesReminderDismissedKey, '1');
    final s = state.value;
    if (s != null) {
      state = AsyncData(
        OnboardingState(
          done: s.done,
          skipped: s.skipped,
          reminderDismissed: true,
        ),
      );
    }
  }
}

/// Montre l'assistant au premier lancement, puis le contenu (qui contient le
/// choix de profil).
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(onboardingProvider);
    return s.when(
      loading: () => const Scaffold(body: StateView.loading()),
      error: (_, _) => child,
      data: (v) => v.done ? child : const OnboardingFlow(),
    );
  }
}

/// Assistant : langue, profil, sources, fin (story 3.0). Aucun addon n'est
/// proposé ni nommé.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  static const _steps = 3;
  int _step = 0;
  int _installed = 0;
  int _kids = 0;
  String? _kidName;
  bool _busy = false;
  final _name = TextEditingController();
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final list = await ref.read(profilesProvider.future);
      if (!mounted || list.isEmpty) return;
      _profile = list.first;
      if (_name.text.isEmpty) _name.text = _profile!.name;
    } on Object {
      // Sans profil lisible, l'étape se contente de continuer.
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _go(int step) {
    ref
        .read(focusMemoryProvider.notifier)
        .remember(onboardingRouteKey, 'step$step');
    setState(() => _step = step);
  }

  void _back() {
    if (_step > 0) {
      _go(_step - 1);
    } else {
      Navigator.maybeOf(context)?.maybePop();
    }
  }

  Future<void> _finish({required bool skipped}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(onboardingProvider.notifier).finish(skipped: skipped);
    } on Object {
      if (mounted) _toast(context.l10n.onboardingSaveError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Étape profil : enregistre le nom saisi (vide ou inchangé : on garde).
  Future<void> _saveNameAndNext() async {
    if (_busy) return;
    final name = _name.text.trim();
    final p = _profile;
    if (p != null && name.isNotEmpty && name != p.name) {
      setState(() => _busy = true);
      try {
        await ref.read(profilesProvider.notifier).edit(p.id, name: name);
        _profile = await ref.read(profileRepositoryProvider).get(p.id);
      } on Object {
        if (mounted) {
          setState(() => _busy = false);
          _toast(context.l10n.onboardingSaveError);
        }
        return;
      }
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) _go(2);
  }

  Future<void> _addKid() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await showTvPanel<ProfileEdit>(
        context,
        builder: (_) => const ProfileEditorDialog(),
      );
      if (result == null || result.delete || !mounted) return;
      if (result.isKid || result.locked) {
        final repo = ref.read(profileRepositoryProvider);
        if (!await repo.hasParentPin()) {
          if (!mounted) return;
          if (!await createParentPinFlow(context, ref)) return;
          if (!mounted || !await repo.hasParentPin()) return;
        }
      }
      await ref
          .read(profilesProvider.notifier)
          .create(
            result.name,
            limit: result.limit,
            isKid: result.isKid,
            locked: result.locked,
          );
      if (mounted) {
        setState(() {
          _kids++;
          _kidName = result.name;
        });
      }
    } on ProfileLimitException {
      if (mounted) _toast(context.l10n.maxProfilesReached);
    } on Object {
      if (mounted) _toast(context.l10n.profileNotModified);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAddon({String? url}) async {
    final ok = await showAddAddonScreen(context, initialUrl: url);
    if (ok && mounted) setState(() => _installed++);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (isTvLayout(context)) return _tvBuild(context);
    return BackGuard(
      isOpen: _step > 0,
      onClose: _back,
      child: TvScaffold(
        onBack: _back,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(LumioSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.onboardingStep(_step + 1, _steps),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: LumioSpacing.md),
                      Flexible(
                        child: SingleChildScrollView(
                          child: KeyedSubtree(
                            key: ValueKey('onboarding-step-$_step'),
                            child: switch (_step) {
                              0 => _languageStep(context),
                              1 => _profileStep(context),
                              _ => _sourcesStep(context),
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: LumioSpacing.lg),
                      Row(
                        children: [
                          if (_step > 0)
                            TextButton(
                              key: const ValueKey('onboarding-back'),
                              onPressed: _busy ? null : _back,
                              child: Text(l.back),
                            ),
                          const Spacer(),
                          TextButton(
                            key: const ValueKey('onboarding-skip'),
                            onPressed: _busy
                                ? null
                                : () => _finish(skipped: true),
                            child: Text(l.onboardingSkip),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- disposition TV (maquettes Main, TV02, TV03) ---

  Widget _tvBuild(BuildContext context) {
    final l = context.l10n;
    final dots = TvStepDots(
      step: _step,
      total: _steps,
      label: l.onboardingStep(_step + 1, _steps),
    );
    final Widget page = switch (_step) {
      0 => _tvLanguage(context, dots),
      1 => _tvProfile(context, dots),
      _ => _tvSources(context, dots),
    };
    return BackGuard(
      isOpen: _step > 0,
      onClose: _back,
      child: TvScaffold(
        onBack: _back,
        child: Scaffold(
          body: KeyedSubtree(
            key: ValueKey('onboarding-step-$_step'),
            child: page,
          ),
        ),
      ),
    );
  }

  Widget _tvHeading(BuildContext context, String title, String? body) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: t.displayLarge?.copyWith(fontSize: 64, height: 1.1),
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Text(
              body,
              style: t.bodyLarge?.copyWith(
                fontSize: 30,
                height: 1.4,
                color: context.lumio.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tvLanguage(BuildContext context, Widget dots) {
    final l = context.l10n;
    final current = ref.watch(localeProvider).languageCode;
    return Row(
      children: [
        TvOnboardingBrandPanel(
          title: l.tvOnbTagline,
          body: l.tvOnbTaglineBody,
          dots: dots,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 140, vertical: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l.onboardingLanguageTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.displayLarge?.copyWith(fontSize: 52),
                  ),
                ),
                const SizedBox(height: 36),
                for (final (code, label) in const [
                  ('fr', 'Français'),
                  ('en', 'English'),
                ]) ...[
                  TvChoiceRow(
                    key: ValueKey('lang-$code'),
                    label: label,
                    selected: current == code,
                    autofocus: current == code,
                    trailing: code == 'fr' ? l.tvOnbDefault : null,
                    onSelect: () async {
                      try {
                        await ref
                            .read(localeProvider.notifier)
                            .set(Locale(code));
                      } on Object {
                        // La langue reste appliquée pour la session.
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                ],
                const Spacer(),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TvButton(
                    key: const ValueKey('onboarding-next'),
                    label: l.continueAction,
                    height: 88,
                    horizontalPadding: 56,
                    fontSize: 30,
                    onPressed: () => _go(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tvFooter(
    BuildContext context, {
    required Widget primary,
    Widget? later,
  }) {
    final l = context.l10n;
    return Row(
      children: [
        if (_step > 0)
          TvButton(
            key: const ValueKey('onboarding-back'),
            kind: TvButtonKind.nav,
            label: l.back,
            fontSize: 30,
            horizontalPadding: 28,
            onPressed: _busy ? null : _back,
          ),
        const Spacer(),
        ?later,
        if (later != null) const SizedBox(width: 32),
        primary,
      ],
    );
  }

  Widget _tvProfile(BuildContext context, Widget dots) {
    final l = context.l10n;
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 140, vertical: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dots,
          const SizedBox(height: 32),
          _tvHeading(context, l.tvOnbProfileHeading, l.tvOnbProfileBody),
          const SizedBox(height: 72),
          Text(
            l.onboardingProfileName,
            style: t.bodyLarge
                ?.weighted(FontWeight.w600)
                .copyWith(fontSize: 28, color: c.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 900,
            child: TvTextField(
              key: const ValueKey('onboarding-name'),
              controller: _name,
              maxLength: 30,
              textInputAction: TextInputAction.done,
              style: t.bodyLarge?.copyWith(fontSize: 36),
              decoration: const InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 28,
                ),
              ),
              onSubmitted: (_) => _saveNameAndNext(),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 900,
            child: FocusableCard(
              key: const ValueKey('onboarding-add-kid'),
              borderRadius: BorderRadius.circular(20),
              semanticLabel: l.onboardingAddKid,
              enabled: !_busy,
              onSelect: _addKid,
              child: Container(
                height: 104,
                padding: const EdgeInsets.symmetric(horizontal: 36),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.onboardingAddKid,
                            style: t.bodyLarge
                                ?.weighted(FontWeight.w600)
                                .copyWith(fontSize: 30, height: 1.2),
                          ),
                          Text(
                            _kids > 0 && _kidName != null
                                ? l.onboardingKidAdded(_kidName!)
                                : l.tvOnbKidBody,
                            style: t.bodyLarge?.copyWith(
                              fontSize: 26,
                              height: 1.2,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.child_care, color: c.textMuted, size: 40),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          _tvFooter(
            context,
            primary: TvButton(
              key: const ValueKey('onboarding-next'),
              autofocus: true,
              label: l.continueAction,
              height: 88,
              horizontalPadding: 56,
              fontSize: 30,
              onPressed: _busy ? null : _saveNameAndNext,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tvSources(BuildContext context, Widget dots) {
    final l = context.l10n;
    final c = context.lumio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 140, vertical: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dots,
          const SizedBox(height: 32),
          _tvHeading(
            context,
            l.onboardingSourcesTitle,
            l.onboardingSourcesBody,
          ),
          const SizedBox(height: 64),
          Wrap(
            spacing: 40,
            runSpacing: 40,
            children: [
              TvSourceCard(
                key: const ValueKey('onboarding-add-addon'),
                autofocus: true,
                icon: Icons.add,
                iconColor: c.accent,
                title: l.tvOnbAddonTitle,
                subtitle: l.tvOnbAddonBody,
                onSelect: () => _addAddon(),
              ),
              TvSourceCard(
                key: const ValueKey('onboarding-add-jellyfin'),
                icon: Icons.dns_outlined,
                iconColor: const Color(0xFFFF8A7A),
                title: l.tvOnbJellyfinTitle,
                subtitle: l.tvOnbJellyfinBody,
                onSelect: _addJellyfin,
              ),
              TvSourceCard(
                key: const ValueKey('onboarding-add-folder'),
                icon: Icons.folder_outlined,
                iconColor: const Color(0xFF9AD66B),
                title: l.tvOnbLocalTitle,
                subtitle: l.tvOnbLocalBody,
                onSelect: () => addLocalFolderFlow(context, ref),
              ),
            ],
          ),
          if (_installed > 0) ...[
            const SizedBox(height: 32),
            Semantics(
              liveRegion: true,
              child: Text(
                l.onboardingAddonsInstalled(_installed),
                key: const ValueKey('onboarding-installed'),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontSize: 30),
              ),
            ),
          ],
          const Spacer(),
          _tvFooter(
            context,
            later: TvButton(
              key: const ValueKey('onboarding-skip'),
              kind: TvButtonKind.nav,
              label: l.tvOnbLater,
              fontSize: 30,
              horizontalPadding: 28,
              onPressed: _busy ? null : () => _finish(skipped: true),
            ),
            primary: TvButton(
              key: const ValueKey('onboarding-finish'),
              label: l.tvOnbFinish,
              height: 88,
              horizontalPadding: 56,
              fontSize: 30,
              onPressed: _busy ? null : () => _finish(skipped: _installed == 0),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addJellyfin() async {
    if (!await requireParent(context, ref)) return;
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      builder: (_) => const JellyfinAddDialog(),
    );
  }

  Widget _title(BuildContext context, String text, [String? body]) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(text, style: theme.textTheme.headlineMedium),
        ),
        if (body != null) ...[
          const SizedBox(height: LumioSpacing.sm),
          Text(body, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: LumioSpacing.lg),
      ],
    );
  }

  Widget _languageStep(BuildContext context) {
    final current = ref.watch(localeProvider).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, context.l10n.onboardingLanguageTitle),
        for (final (code, label) in const [
          ('fr', 'Français'),
          ('en', 'English'),
        ]) ...[
          _ChoiceCard(
            key: ValueKey('lang-$code'),
            label: label,
            selected: current == code,
            autofocus: current == code,
            onSelect: () async {
              try {
                await ref.read(localeProvider.notifier).set(Locale(code));
              } on Object {
                // La langue reste appliquée pour la session.
              }
            },
          ),
          const SizedBox(height: LumioSpacing.sm),
        ],
        const SizedBox(height: LumioSpacing.md),
        FilledButton(
          key: const ValueKey('onboarding-next'),
          onPressed: () => _go(1),
          child: Text(context.l10n.continueAction),
        ),
      ],
    );
  }

  Widget _profileStep(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, l.onboardingProfileTitle, l.onboardingProfileBody),
        TvTextField(
          key: const ValueKey('onboarding-name'),
          controller: _name,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: l.onboardingProfileName),
          onSubmitted: (_) => _saveNameAndNext(),
        ),
        const SizedBox(height: LumioSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('onboarding-add-kid'),
            onPressed: _busy ? null : _addKid,
            icon: const Icon(Icons.child_care),
            label: Text(l.onboardingAddKid),
          ),
        ),
        if (_kids > 0 && _kidName != null)
          Padding(
            padding: const EdgeInsets.only(top: LumioSpacing.sm),
            child: Text(l.onboardingKidAdded(_kidName!)),
          ),
        const SizedBox(height: LumioSpacing.lg),
        FilledButton(
          key: const ValueKey('onboarding-next'),
          autofocus: true,
          onPressed: _busy ? null : _saveNameAndNext,
          child: Text(l.continueAction),
        ),
      ],
    );
  }

  Widget _sourcesStep(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, l.onboardingSourcesTitle, l.onboardingSourcesBody),
        FilledButton.icon(
          key: const ValueKey('onboarding-add-addon'),
          autofocus: true,
          onPressed: () => _addAddon(),
          icon: const Icon(Icons.extension),
          label: Text(l.addAddon),
        ),
        const SizedBox(height: LumioSpacing.sm),
        OutlinedButton.icon(
          key: const ValueKey('onboarding-add-folder'),
          onPressed: () => addLocalFolderFlow(context, ref),
          icon: const Icon(Icons.folder_open),
          label: Text(l.localAddFolder),
        ),
        if (_installed > 0) ...[
          const SizedBox(height: LumioSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              l.onboardingAddonsInstalled(_installed),
              key: const ValueKey('onboarding-installed'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
        const SizedBox(height: LumioSpacing.lg),
        Text(
          l.onboardingDoneBody,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: LumioSpacing.md),
        FilledButton(
          key: const ValueKey('onboarding-finish'),
          onPressed: _busy ? null : () => _finish(skipped: _installed == 0),
          child: Text(_installed > 0 ? l.onboardingStart : l.continueAction),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelect,
    this.autofocus = false,
  });

  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return FocusableCard(
      autofocus: autofocus,
      onSelect: onSelect,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.all(LumioSpacing.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(LumioRadius.md),
          border: Border.all(color: selected ? c.accent : Colors.transparent),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (selected) Icon(Icons.check, color: c.accent),
          ],
        ),
      ),
    );
  }
}

/// Rappel discret sur l'accueil après un « Passer » : masquable, la
/// dismissal est mémorisée.
class SourcesReminderCard extends ConsumerWidget {
  const SourcesReminderCard({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(
      onboardingProvider.select((s) => s.value?.showReminder ?? false),
    );
    final hasAddons = ref.watch(
      addonsProvider.select((s) => (s.value ?? const []).isNotEmpty),
    );
    if (!show || hasAddons) return const SizedBox.shrink();
    final l = context.l10n;
    final c = context.lumio;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 96,
        end: LumioSpacing.xl,
        bottom: LumioSpacing.sm,
      ),
      child: Container(
        key: const ValueKey('sources-reminder'),
        padding: const EdgeInsets.all(LumioSpacing.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(LumioRadius.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.sourcesReminderTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    l.sourcesReminderBody,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onAdd, child: Text(l.addAddon)),
            TextButton(
              key: const ValueKey('sources-reminder-dismiss'),
              onPressed: () async {
                try {
                  await ref.read(onboardingProvider.notifier).dismissReminder();
                } on Object {
                  // Le rappel reste affiché ; réessayer est possible.
                }
              },
              child: Text(l.sourcesReminderDismiss),
            ),
          ],
        ),
      ),
    );
  }
}

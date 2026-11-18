import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/profiles/pin_dialog.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

/// Un profil est protégé par le PIN parent s'il est marqué « verrouillé », ou
/// si c'est un profil adulte alors qu'un profil enfant et un PIN existent :
/// sans cela, l'enfant n'aurait qu'à choisir l'adulte à l'écran de choix.
bool isProfileLocked(Profile p, List<Profile> all, {required bool hasPin}) {
  if (!hasPin) return false;
  if (p.locked) return true;
  return !p.isKid && all.any((x) => x.isKid);
}

/// Mention d'âge d'un profil enfant (« Enfant · 12+ »).
String kidLabel(Profile p) {
  final years = AgeLimit.values[p.ageLimit].years;
  return years == null ? 'Enfant · Tous publics' : 'Enfant · $years+';
}

/// Affiche le contenu quand un profil est actif ; sinon choisit seul l'unique
/// profil, ou présente le sélecteur quand il y en a au moins deux.
class ProfileGate extends ConsumerWidget {
  const ProfileGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentProfileProvider);
    if (current != null) return child;
    final profiles = ref.watch(profilesProvider);
    return profiles.when(
      loading: () => const Scaffold(body: StateView.loading()),
      error: (_, _) => Scaffold(
        body: StateView.error(
          message: 'Impossible de charger les profils',
          onRetry: () => ref.invalidate(profilesProvider),
        ),
      ),
      data: (list) {
        if (list.length == 1 &&
            !ref.watch(profileManagementRequestedProvider)) {
          // Un seul profil : choisi automatiquement.
          Future.microtask(() {
            if (context.mounted && ref.read(currentProfileProvider) == null) {
              ref.read(currentProfileProvider.notifier).select(list.single);
            }
          });
          return const Scaffold(body: StateView.loading());
        }
        return const ProfilePickerScreen();
      },
    );
  }
}

/// Choix du profil (avatars 200 dp ; verrou = cadenas + « PIN » ; mention
/// d'âge pour les profils enfants) et gestion des profils.
class ProfilePickerScreen extends ConsumerStatefulWidget {
  const ProfilePickerScreen({super.key});

  @override
  ConsumerState<ProfilePickerScreen> createState() =>
      _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends ConsumerState<ProfilePickerScreen> {
  late bool _manage = ref.read(profileManagementRequestedProvider);
  // Échec fermé : tant qu'on ignore s'il existe un PIN, on le suppose requis.
  bool _hasPin = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshPin();
  }

  /// Relit l'existence du PIN. Faux (avec message) si la lecture échoue :
  /// l'action protégée doit alors être refusée.
  Future<bool> _refreshPin() async {
    try {
      final has = await ref.read(profileRepositoryProvider).hasParentPin();
      if (mounted) setState(() => _hasPin = has);
      return true;
    } on Object {
      if (mounted) {
        setState(() => _hasPin = true);
        _toast('Contrôle parental indisponible. Réessayez.');
      }
      return false;
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Évite les ouvertures concurrentes (double appui sur OK).
  Future<void> _guard(Future<void> Function() op) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await op();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Profile p, List<Profile> all) => _guard(() async {
    if (_manage) {
      await _edit(p);
      return;
    }
    if (!await _refreshPin() || !mounted) return;
    if (isProfileLocked(p, all, hasPin: _hasPin)) {
      final ok = await verifyParentPinFlow(
        context,
        ref,
        title: 'PIN pour ${p.name}',
      );
      if (!ok || !mounted) return;
    }
    ref.read(profileManagementRequestedProvider.notifier).set(false);
    ref.read(currentProfileProvider.notifier).select(p);
  });

  Future<void> _toggleManage() => _guard(() async {
    if (_manage) {
      setState(() => _manage = false);
      return;
    }
    if (!await _refreshPin() || !mounted) return;
    if (_hasPin && !await verifyParentPinFlow(context, ref)) return;
    if (mounted) setState(() => _manage = true);
  });

  Future<void> _add() => _guard(() async {
    if (!await _refreshPin() || !mounted) return;
    if (_hasPin && !await verifyParentPinFlow(context, ref)) return;
    if (!mounted) return;
    await _edit(null);
  });

  Future<void> _edit(Profile? p) async {
    final result = await showDialog<ProfileEdit>(
      context: context,
      builder: (_) => ProfileEditorDialog(profile: p),
    );
    if (result == null || !mounted) return;
    final ctl = ref.read(profilesProvider.notifier);
    try {
      if (result.delete && p != null) {
        await ctl.delete(p.id);
        return;
      }
      // Un profil enfant ou verrouillé suppose un PIN parent.
      if ((result.isKid || result.locked) && !await _ensurePin()) return;
      if (p == null) {
        await ctl.create(
          result.name,
          limit: result.limit,
          isKid: result.isKid,
          locked: result.locked,
        );
      } else {
        await ctl.edit(
          p.id,
          name: result.name,
          limit: result.limit,
          isKid: result.isKid,
          locked: result.locked,
        );
      }
    } on ProfileLimitException {
      _toast('Six profils au maximum');
    } on Object {
      _toast('Action impossible : le profil n\'a pas été modifié');
    }
  }

  Future<bool> _ensurePin() async {
    if (!await _refreshPin() || !mounted) return false;
    if (_hasPin) return true;
    final ok = await createParentPinFlow(context, ref);
    if (!mounted) return false;
    return await _refreshPin() && ok;
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(profilesProvider).value ?? const <Profile>[];
    final theme = Theme.of(context);
    final c = context.lumio;
    return Scaffold(
      body: TvScaffold(
        onBack: _manage ? () => setState(() => _manage = false) : () {},
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(LumioSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _manage ? 'Gérer les profils' : 'Qui regarde ?',
                    style: theme.textTheme.displayLarge,
                  ),
                  const SizedBox(height: LumioSpacing.xl),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: LumioSpacing.xl,
                    runSpacing: LumioSpacing.xl,
                    children: [
                      for (var i = 0; i < list.length; i++)
                        _ProfileTile(
                          key: ValueKey('profile-${list[i].id}'),
                          profile: list[i],
                          color: _avatarColors[i % _avatarColors.length],
                          locked: isProfileLocked(
                            list[i],
                            list,
                            hasPin: _hasPin,
                          ),
                          manage: _manage,
                          autofocus: i == 0,
                          onSelect: () => _open(list[i], list),
                        ),
                      if (list.length < maxProfiles) _AddTile(onSelect: _add),
                    ],
                  ),
                  const SizedBox(height: LumioSpacing.xl),
                  OutlinedButton.icon(
                    onPressed: _toggleManage,
                    icon: Icon(_manage ? Icons.check : Icons.edit_outlined),
                    label: Text(_manage ? 'Terminé' : 'Gérer les profils'),
                    style: OutlinedButton.styleFrom(foregroundColor: c.text),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Couleurs d'avatar (ambre, turquoise et teintes sobres ; aucun violet).
const _avatarColors = [
  Color(0xFFFFB84D),
  Color(0xFF4FD1C5),
  Color(0xFFFF8A65),
  Color(0xFF5BD68A),
  Color(0xFF64B5F6),
  Color(0xFFE6C17A),
];

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    super.key,
    required this.profile,
    required this.color,
    required this.locked,
    required this.manage,
    required this.autofocus,
    required this.onSelect,
  });

  final Profile profile;
  final Color color;
  final bool locked;
  final bool manage;
  final bool autofocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final theme = Theme.of(context);
    final name = profile.name;
    final initial = name.characters.isEmpty ? '?' : name.characters.first;
    final sub = profile.isKid ? kidLabel(profile) : null;
    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FocusableCard(
            autofocus: autofocus,
            semanticLabel: [
              name,
              ?sub,
              if (locked) 'verrouillé, PIN demandé',
              if (manage) 'modifier',
            ].join(', '),
            borderRadius: BorderRadius.circular(LumioRadius.pill),
            onSelect: onSelect,
            child: Container(
              width: 200,
              height: 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    initial.toUpperCase(),
                    style: TextStyle(
                      color: c.onAccent,
                      fontSize: 84,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (locked)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(LumioSpacing.sm),
                        decoration: BoxDecoration(
                          color: c.bg.withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock, color: c.text, size: 28),
                      ),
                    ),
                  if (manage)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(LumioSpacing.sm),
                        decoration: BoxDecoration(
                          color: c.bg.withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit, color: c.text, size: 28),
                      ),
                    ),
                ],
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelect,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: LumioSpacing.md),
                Text(
                  name,
                  style: theme.textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (locked)
                  Text(
                    'PIN',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: c.textMuted,
                    ),
                  ),
                if (sub != null)
                  Text(
                    sub,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: c.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onSelect});
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FocusableCard(
            semanticLabel: 'Ajouter un profil',
            borderRadius: BorderRadius.circular(LumioRadius.pill),
            onSelect: onSelect,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceRaised,
                border: Border.all(color: c.outline, width: 2),
              ),
              child: Icon(Icons.add, size: 72, color: c.textMuted),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelect,
            child: Padding(
              padding: const EdgeInsets.only(top: LumioSpacing.md),
              child: Text(
                'Ajouter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Résultat de l'éditeur de profil.
class ProfileEdit {
  const ProfileEdit({
    required this.name,
    required this.limit,
    required this.isKid,
    required this.locked,
    this.delete = false,
  });

  final String name;
  final AgeLimit limit;
  final bool isKid;
  final bool locked;
  final bool delete;
}

/// Création / modification d'un profil (nom, enfant, limite d'âge,
/// verrouillage, suppression).
class ProfileEditorDialog extends StatefulWidget {
  const ProfileEditorDialog({super.key, this.profile});

  final Profile? profile;

  @override
  State<ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<ProfileEditorDialog> {
  late final TextEditingController _name;
  late bool _kid;
  late bool _locked;
  late AgeLimit _limit;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _kid = p?.isKid ?? false;
    _locked = p?.locked ?? false;
    final stored = p == null ? AgeLimit.age12 : AgeLimit.values[p.ageLimit];
    _limit = stored == AgeLimit.adult ? AgeLimit.age12 : stored;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Donnez un nom au profil');
      return;
    }
    Navigator.of(context).pop(
      ProfileEdit(
        name: name,
        limit: _kid ? _limit : AgeLimit.adult,
        isKid: _kid,
        locked: _locked,
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce profil ?'),
        content: const Text(
          'Sa progression, sa liste et ses réglages seront supprimés.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ctx.lumio.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(
        const ProfileEdit(
          name: '',
          limit: AgeLimit.adult,
          isKid: false,
          locked: false,
          delete: true,
        ),
      );
    }
  }

  static const _limits = [
    (AgeLimit.all, 'Tous publics'),
    (AgeLimit.age7, '7+'),
    (AgeLimit.age12, '12+'),
    (AgeLimit.age16, '16+'),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.profile == null ? 'Nouveau profil' : 'Modifier le profil',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: 20,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Nom',
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _save(),
              ),
              SwitchListTile(
                value: _kid,
                onChanged: (v) => setState(() => _kid = v),
                title: const Text('Profil enfant'),
                subtitle: const Text(
                  'Contenus filtrés selon l\'âge ; réglages et changement de '
                  'profil protégés par le PIN parent.',
                ),
              ),
              if (_kid) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: LumioSpacing.sm),
                  child: Text('Limite d\'âge'),
                ),
                Wrap(
                  spacing: LumioSpacing.sm,
                  children: [
                    for (final (limit, label) in _limits)
                      ChoiceChip(
                        label: Text(label),
                        selected: _limit == limit,
                        onSelected: (_) => setState(() => _limit = limit),
                      ),
                  ],
                ),
              ],
              if (!_kid)
                SwitchListTile(
                  value: _locked,
                  onChanged: (v) => setState(() => _locked = v),
                  title: const Text('Verrouiller par PIN'),
                  subtitle: const Text(
                    'Le PIN parent est demandé pour ouvrir ce profil.',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.profile != null)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: context.lumio.error),
            child: const Text('Supprimer'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _save, child: const Text('Enregistrer')),
      ],
    );
  }
}

/// Bouton de profil de la barre haute : change de profil (PIN parent pour un
/// profil enfant) ; avec un seul profil, ouvre la gestion des profils pour en
/// ajouter, créer le PIN parent ou renommer « Moi ».
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return TextButton.icon(
      onPressed: () async {
        final repo = ref.read(profileRepositoryProvider);
        final single = (ref.read(profilesProvider).value?.length ?? 0) <= 1;
        if (single) {
          // Gestion : protégée par le PIN s'il existe (échec fermé).
          final bool hasPin;
          try {
            hasPin = await repo.hasParentPin();
          } on Object {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contrôle parental indisponible. Réessayez.'),
                ),
              );
            }
            return;
          }
          if (!context.mounted) return;
          if (hasPin && !await verifyParentPinFlow(context, ref)) return;
          ref.read(profileManagementRequestedProvider.notifier).set(true);
        } else if (!await requireParent(context, ref)) {
          return;
        }
        ref.read(currentProfileProvider.notifier).select(null);
      },
      icon: const Icon(Icons.account_circle_outlined),
      label: Text(profile?.name ?? 'Profil'),
    );
  }
}

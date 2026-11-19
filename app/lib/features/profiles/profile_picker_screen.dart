import 'package:flutter/material.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/common/tv_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/features/profiles/pin_dialog.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
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

/// Un profil enfant sans PIN parent sur l'appareil (typiquement reçu d'un
/// autre appareil par une sauvegarde importée) n'est pas sélectionnable : rien ne
/// l'empêcherait de quitter le profil. Un PIN doit d'abord être créé.
bool kidProfileNeedsPin(Profile p, {required bool hasPin}) =>
    p.isKid && !hasPin;

/// Mention d'âge d'un profil enfant (« Enfant · 12+ »).
String kidLabel(Profile p, [AppLocalizations? l]) {
  l ??= AppLocalizationsFr();
  final years = AgeLimit.values[p.ageLimit].years;
  return years == null ? l.kidAllAges : l.kidYears(years);
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
          message: context.l10n.profilesLoadError,
          onRetry: () => ref.invalidate(profilesProvider),
        ),
      ),
      data: (list) {
        // Un profil enfant seul n'est pas choisi d'office : le sélecteur
        // vérifie qu'un PIN parent existe (voir kidProfileNeedsPin).
        if (list.length == 1 &&
            !list.single.isKid &&
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
        _toast(context.l10n.parentalUnavailable);
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
    if (kidProfileNeedsPin(p, hasPin: _hasPin)) {
      _toast(context.l10n.kidProfileNeedsPin);
      final created = await createParentPinFlow(context, ref);
      if (!created || !mounted) return;
      if (!await _refreshPin() || !mounted || !_hasPin) return;
    }
    if (isProfileLocked(p, all, hasPin: _hasPin)) {
      final ok = await verifyParentPinFlow(
        context,
        ref,
        title: context.l10n.pinFor(p.name),
      );
      if (!ok || !mounted) return;
    }
    ref.read(profileManagementRequestedProvider.notifier).set(false);
    ref.read(previousProfileProvider.notifier).set(null);
    ref.read(currentProfileProvider.notifier).select(p);
  });

  /// Retour : quitte la gestion, puis revient à l'accueil (profil précédent).
  void _back() {
    if (_manage) {
      setState(() => _manage = false);
      return;
    }
    final prev = ref.read(previousProfileProvider);
    if (prev == null) return;
    ref.read(previousProfileProvider.notifier).set(null);
    ref.read(profileManagementRequestedProvider.notifier).set(false);
    ref.read(currentProfileProvider.notifier).select(prev);
  }

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
    final result = await showTvPanel<ProfileEdit>(
      context,
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
      if (mounted) _toast(context.l10n.maxProfilesReached);
    } on Object {
      if (mounted) _toast(context.l10n.profileNotModified);
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
    final c = context.lumio;
    final l = context.l10n;
    final memory = ref.read(focusMemoryProvider.notifier);
    var remembered = memory.restore(profilesRouteKey);
    if (!list.any((p) => p.id == remembered)) remembered = null;
    // TV04 (choix) et TV35 (gestion) : titre 72 centré, avatars 200 en ligne.
    final gap = _manage ? 88.0 : 96.0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: TvScaffold(
          onBack: _back,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 0.9,
                      colors: [Color(0xFF1B2A33), Color(0xFF0E1116)],
                    ),
                  ),
                ),
              ),
              if (_manage) ...[
                Positioned(
                  top: 90,
                  left: 0,
                  right: 0,
                  child: Text(
                    l.whoIsWatching,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 72,
                      fontWeight: FontWeight.w700,
                      fontVariations: [FontVariation.weight(700)],
                      height: 1.15,
                    ),
                  ),
                ),
                Positioned(
                  top: 290,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < list.length; i++) ...[
                            if (i > 0) SizedBox(width: gap),
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
                              autofocus: remembered == null
                                  ? i == 0
                                  : list[i].id == remembered,
                              onFocus: () =>
                                  memory.remember(profilesRouteKey, list[i].id),
                              onSelect: () => _open(list[i], list),
                            ),
                          ],
                          if (list.length < maxProfiles) ...[
                            if (list.isNotEmpty) SizedBox(width: gap),
                            _AddTile(manage: _manage, onSelect: _add),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ] else
                // TV04 : titre + avatars centrés verticalement à l'écran.
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.whoIsWatching,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 72,
                            fontWeight: FontWeight.w700,
                            fontVariations: [FontVariation.weight(700)],
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 107),
                        Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < list.length; i++) ...[
                                  if (i > 0) SizedBox(width: gap),
                                  _ProfileTile(
                                    key: ValueKey('profile-${list[i].id}'),
                                    profile: list[i],
                                    color:
                                        _avatarColors[i % _avatarColors.length],
                                    locked: isProfileLocked(
                                      list[i],
                                      list,
                                      hasPin: _hasPin,
                                    ),
                                    manage: _manage,
                                    autofocus: remembered == null
                                        ? i == 0
                                        : list[i].id == remembered,
                                    onFocus: () => memory.remember(
                                      profilesRouteKey,
                                      list[i].id,
                                    ),
                                    onSelect: () => _open(list[i], list),
                                  ),
                                ],
                                if (list.length < maxProfiles) ...[
                                  if (list.isNotEmpty) SizedBox(width: gap),
                                  _AddTile(manage: _manage, onSelect: _add),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_manage) ...[
                Positioned(
                  top: 760,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: TvButton(
                      key: const ValueKey('profiles-done'),
                      label: l.done,
                      height: 76,
                      fontSize: 28,
                      horizontalPadding: 40,
                      icon: LumioIconView(
                        LumioIcon.check,
                        size: 32,
                        color: c.onAccent,
                      ),
                      onPressed: _toggleManage,
                    ),
                  ),
                ),
                Positioned(
                  top: 880,
                  left: 0,
                  right: 0,
                  child: Text(
                    l.manageProfilesHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, color: c.textMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Clé de la mémoire du focus du sélecteur de profil.
const profilesRouteKey = 'profiles';

/// Couleurs d'avatar (ambre, turquoise et teintes sobres ; aucun violet).
const _avatarColors = [
  Color(0xFFFFB84D),
  Color(0xFF4FD1C5),
  Color(0xFFFF8A65),
  Color(0xFF5BD68A),
  Color(0xFF64B5F6),
  Color(0xFFE6C17A),
];

/// Pastille ronde 60 dp des badges d'avatar (TV35).
Widget _avatarBadge(Color bg, LumioIcon icon, double size, Color fg) =>
    Container(
      width: 60,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: LumioIconView(icon, size: size, color: fg),
    );

/// Avatar focalisable : cercle de 200 dp, anneau à 8 dp, échelle 1,08.
Widget _avatarCard({
  required bool autofocus,
  required String label,
  required VoidCallback onSelect,
  VoidCallback? onFocus,
  required Widget circle,
}) => SizedBox(
  width: 200,
  height: 200,
  child: OverflowBox(
    maxWidth: 208,
    maxHeight: 208,
    child: FocusableCard(
      autofocus: autofocus,
      scale: 1.08,
      onFocusChange: (f) {
        if (f) onFocus?.call();
      },
      semanticLabel: label,
      borderRadius: BorderRadius.circular(104),
      onSelect: onSelect,
      child: SizedBox(width: 208, height: 208, child: Center(child: circle)),
    ),
  ),
);

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    super.key,
    required this.profile,
    required this.color,
    required this.locked,
    required this.manage,
    required this.autofocus,
    required this.onSelect,
    required this.onFocus,
  });

  final Profile profile;
  final Color color;
  final bool locked;
  final bool manage;
  final bool autofocus;
  final VoidCallback onSelect;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final l = context.l10n;
    final name = profile.name;
    final initial = name.characters.isEmpty ? '?' : name.characters.first;
    final kid = profile.isKid ? kidLabel(profile, l) : null;
    // Gestion : « Adulte · PIN » ; choix : mention d'âge + cadenas « PIN ».
    final manageSub = [
      kid ?? l.profileAdultShort,
      if (locked) l.pinBadge,
    ].join(' · ');
    final sub = manage ? manageSub : kid;
    final subStyle = TextStyle(fontSize: manage ? 24 : 26, color: c.textMuted);
    return SizedBox(
      width: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _avatarCard(
            autofocus: autofocus,
            onFocus: onFocus,
            label: [
              name,
              ?sub,
              if (locked) l.lockedSemantic,
              if (manage) l.editSemantic,
            ].join(', '),
            onSelect: onSelect,
            circle: Container(
              width: 200,
              height: 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Text(
                      initial.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Bricolage Grotesque',
                        color: c.onAccent,
                        fontSize: 88,
                        fontWeight: FontWeight.w700,
                        fontVariations: const [FontVariation.weight(700)],
                      ),
                    ),
                  ),
                  if (manage) ...[
                    Positioned(
                      left: 0,
                      top: 0,
                      child: _avatarBadge(c.bg, LumioIcon.pencil, 30, c.text),
                    ),
                    if (locked)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: _avatarBadge(
                          c.bg,
                          LumioIcon.lockSolid,
                          32,
                          c.text,
                        ),
                      ),
                  ],
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
                SizedBox(height: manage ? 14 : 20),
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    fontVariations: [FontVariation.weight(600)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (!manage && locked) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LumioIconView(
                        LumioIcon.lock,
                        size: 24,
                        color: c.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(l.pinBadge, style: subStyle),
                    ],
                  ),
                ],
                if (sub != null && (manage || kid != null)) ...[
                  SizedBox(height: manage ? 14 : 20),
                  Text(sub, style: subStyle, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.manage, required this.onSelect});
  final bool manage;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final l = context.l10n;
    return SizedBox(
      width: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _avatarCard(
            autofocus: false,
            label: l.addProfileSemantic,
            onSelect: onSelect,
            circle: CustomPaint(
              foregroundPainter: _DashedCirclePainter(const Color(0xFF5B6676)),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surface,
                ),
                // TV04 : signe « + » en police de titre (72) ; TV35 : icône SVG.
                child: manage
                    ? LumioIconView(
                        LumioIcon.plus,
                        size: 72,
                        color: c.textMuted,
                      )
                    : Center(
                        child: Text(
                          '+',
                          style: TextStyle(
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 72,
                            fontWeight: FontWeight.w700,
                            fontVariations: const [FontVariation.weight(700)],
                            color: c.textMuted,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelect,
            child: Padding(
              padding: EdgeInsets.only(top: manage ? 14 : 20),
              child: SizedBox(
                width: 200,
                child: Text(
                  manage ? l.addProfileSemantic : l.add,
                  textAlign: TextAlign.center,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    fontVariations: [FontVariation.weight(600)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cercle en pointillés (bordure 3 dp) du bouton « Ajouter ».
class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final r = size.width / 2 - 1.5;
    final center = Offset(size.width / 2, size.height / 2);
    const dashes = 36;
    for (var i = 0; i < dashes; i++) {
      final start = i * 2 * 3.141592653589793 / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        2 * 3.141592653589793 / dashes * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
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
      setState(() => _error = context.l10n.nameRequired);
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
    final ok = await showTvConfirm(
      context,
      title: context.l10n.deleteProfileTitle,
      body: context.l10n.deleteProfileBody,
      confirmLabel: context.l10n.delete,
      destructive: true,
    );
    if (ok && mounted) {
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

  static List<(AgeLimit, String)> _limits(AppLocalizations l) => [
    (AgeLimit.all, l.ageAll),
    (AgeLimit.age7, '7+'),
    (AgeLimit.age12, '12+'),
    (AgeLimit.age16, '16+'),
  ];

  /// Ligne à interrupteur du pop-up (maquette P02 : fond #0E1116, 104 min).
  Widget _switchRow({
    required Key key,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final c = context.lumio;
    return Semantics(
      toggled: value,
      child: FocusableCard(
        key: key,
        scale: 1.01,
        borderRadius: BorderRadius.circular(22),
        semanticLabel: title,
        onSelect: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontVariations: [FontVariation.weight(700)],
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.35,
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              TvSwitch(value: value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final c = context.lumio;
    return FocusableCard(
      scale: 1.04,
      borderRadius: BorderRadius.circular(32),
      semanticLabel: label,
      onSelect: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surfaceFocus,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation.weight(700)],
            color: selected ? c.onAccent : c.text,
          ),
        ),
      ),
    );
  }

  Widget _textButton(
    String label,
    Color color,
    VoidCallback onTap, {
    Key? key,
  }) => FocusableCard(
    key: key,
    scale: 1.04,
    borderRadius: BorderRadius.circular(38),
    semanticLabel: label,
    onSelect: onTap,
    child: Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          fontVariations: const [FontVariation.weight(600)],
          color: color,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    return TvPanel(
      title: widget.profile == null ? l.newProfile : l.editProfile,
      width: 1000,
      onBack: () => Navigator.of(context).pop(),
      actions: [
        Expanded(
          child: Row(
            children: [
              if (widget.profile != null)
                _textButton(l.delete, c.error, _delete),
              const Spacer(),
              _textButton(l.cancel, const Color(0xFFC9D0DA), () {
                Navigator.of(context).pop();
              }),
              const SizedBox(width: 16),
              TvButton(
                label: l.save,
                height: 76,
                fontSize: 28,
                horizontalPadding: 40,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ],
      children: [
        Text(
          l.nameLabel,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            fontVariations: const [FontVariation.weight(600)],
            color: c.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        FocusRing(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.outline, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TvTextField(
                    controller: _name,
                    autofocus: true,
                    maxLength: 20,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      fontVariations: [FontVariation.weight(600)],
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      counterText: '',
                      isCollapsed: true,
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                      setState(() {});
                    },
                    onSubmitted: (_) => _save(),
                  ),
                ),
                Text(
                  '${_name.text.characters.length}/20',
                  style: TextStyle(fontSize: 24, color: c.textMuted),
                ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 26, color: c.error),
                const SizedBox(width: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: c.error,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        _switchRow(
          key: const ValueKey('profile-kid'),
          title: l.kidProfile,
          subtitle: l.kidProfileHint,
          value: _kid,
          onChanged: (v) => setState(() => _kid = v),
        ),
        const SizedBox(height: 20),
        if (_kid) ...[
          Text(
            l.ageLimit,
            style: const TextStyle(fontSize: 28, color: Color(0xFFC9D0DA)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              for (final (limit, label) in _limits(l))
                _chip(
                  label,
                  _limit == limit,
                  () => setState(() => _limit = limit),
                ),
            ],
          ),
        ] else
          _switchRow(
            key: const ValueKey('profile-lock'),
            title: l.lockByPin,
            subtitle: l.lockByPinHint,
            value: _locked,
            onChanged: (v) => setState(() => _locked = v),
          ),
        const SizedBox(height: 20),
        Text(
          l.profileEditorHint,
          style: TextStyle(fontSize: 24, height: 1.35, color: c.textMuted),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Bouton de profil de la barre haute : change de profil (PIN parent pour un
/// profil enfant) ; avec un seul profil, ouvre la gestion des profils pour en
/// ajouter, créer le PIN parent ou renommer « Moi ».
/// Changement de profil depuis l'accueil : avec un seul profil, gestion
/// protégée par le PIN s'il existe (échec fermé) ; sinon PIN parent requis.
Future<void> switchProfileFlow(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? beforeSelect,
  bool manage = false,
}) async {
  final repo = ref.read(profileRepositoryProvider);
  final single = (ref.read(profilesProvider).value?.length ?? 0) <= 1;
  if (manage && !single) {
    // Gestion demandée depuis les réglages : le PIN parent est exigé s'il existe.
    final bool hasPin;
    try {
      hasPin = await repo.hasParentPin();
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.parentalUnavailable)),
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (hasPin && !await verifyParentPinFlow(context, ref)) return;
    ref.read(profileManagementRequestedProvider.notifier).set(true);
  } else if (single) {
    final bool hasPin;
    try {
      hasPin = await repo.hasParentPin();
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.parentalUnavailable)),
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
  ref
      .read(previousProfileProvider.notifier)
      .set(ref.read(currentProfileProvider));
  // Retire les écrans empilés (Réglages…) pour laisser voir le sélecteur.
  beforeSelect?.call();
  ref.read(currentProfileProvider.notifier).select(null);
}

class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return TextButton.icon(
      onPressed: () => switchProfileFlow(context, ref),
      icon: const Icon(Icons.account_circle_outlined),
      label: Text(profile?.name ?? context.l10n.profileFallback),
    );
  }
}

import 'package:lumio/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:lumio/ui/common/tv_screen.dart' show tvHeaderHeight;
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
import 'package:lumio/ui/theme.dart';

/// Composant commun des états d'écran : chargement, vide, erreur.
///
/// Les textes sont fournis par l'appelant (traduits via gen-l10n) ; le
/// libellé du bouton d'erreur est par défaut « Réessayer » (traduit).
class StateView extends StatelessWidget {
  const StateView.loading({super.key})
    : _kind = _Kind.loading,
      message = null,
      actionLabel = null,
      onAction = null,
      headerInset = null;

  const StateView.empty({
    required String this.message,
    this.actionLabel,
    this.onAction,
    this.headerInset,
    super.key,
  }) : _kind = _Kind.empty;

  const StateView.error({
    required String this.message,
    required VoidCallback onRetry,
    String? retryLabel,
    this.headerInset,
    super.key,
  }) : _kind = _Kind.error,
       actionLabel = retryLabel,
       onAction = onRetry;

  final _Kind _kind;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Hauteur d'en-tête au-dessus de la zone (TV) : les maquettes centrent
  /// l'état dans tout l'écran 1080, pas sous l'en-tête (défaut : 152).
  final double? headerInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_kind == _Kind.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final isError = _kind == _Kind.error;
    if (isTvLayout(context)) {
      // TV : pastille d'icône 96, texte 34, bouton 76 (maquettes `.emp` de
      // TV41/TV42/TV45/TV46).
      final c = context.lumio;
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            48,
            48,
            48,
            48 + (headerInset ?? tvHeaderHeight),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.surface,
                  ),
                  child: LumioIconView(
                    isError ? LumioIcon.alert : LumioIcon.inbox,
                    size: 48,
                    color: isError ? c.error : c.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 34,
                    color: const Color(0xFFC9D0DA),
                  ),
                ),
                if (onAction != null) ...[
                  const SizedBox(height: 36),
                  TvButton(
                    autofocus: true,
                    label: actionLabel ?? context.l10n.retry,
                    height: 76,
                    horizontalPadding: 40,
                    fontSize: 28,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.inbox_outlined,
              size: 48,
              color: isError
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel ?? context.l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Kind { loading, empty, error }

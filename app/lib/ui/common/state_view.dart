import 'package:flutter/material.dart';

/// Composant commun des états d'écran : chargement, vide, erreur.
///
/// Les textes sont fournis par l'appelant (traduits via gen-l10n) ; seul le
/// libellé du bouton d'erreur a une valeur par défaut française.
class StateView extends StatelessWidget {
  const StateView.loading({super.key})
    : _kind = _Kind.loading,
      message = null,
      actionLabel = null,
      onAction = null;

  const StateView.empty({
    required String this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : _kind = _Kind.empty;

  const StateView.error({
    required String this.message,
    required VoidCallback onRetry,
    String retryLabel = 'Réessayer',
    super.key,
  }) : _kind = _Kind.error,
       actionLabel = retryLabel,
       onAction = onRetry;

  final _Kind _kind;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_kind == _Kind.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final isError = _kind == _Kind.error;
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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Kind { loading, empty, error }

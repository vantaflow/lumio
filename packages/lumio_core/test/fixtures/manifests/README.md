# Corpus de manifests

Entrées du futur analyseur de manifests (Task 6). Les verdicts ci-dessous sont
les résultats attendus ; « invalide » signifie une erreur claire, jamais un
plantage.

| Fichier | Verdict attendu |
|---|---|
| `valid_minimal.json` | valide : seuls `id`, `version`, `name`, `resources`, `types`, `catalogs` |
| `valid_full.json` | valide : tous les champs, ressources mixtes (chaîne et objet), `extra`, `behaviorHints` |
| `missing_id.json` | invalide : `id` absent |
| `resources_object.json` | invalide : `resources` est un objet au lieu d'une liste |
| `unknown_types.json` | valide : types inconnus (`hologram`, `podcast`) conservés tels quels, sans erreur |
| `truncated.json` | invalide : JSON tronqué (erreur de syntaxe) |
| `html_instead_of_json.json` | invalide : page HTML au lieu de JSON |
| `null_field.json` | valide : `description`, `logo`, `background`, `name` de catalogue à `null` traités comme absents |
| `unicode_arabic.json` | valide : textes arabes (RTL) restitués intacts |
| `version_not_semver.json` | valide avec avertissement : `version` non semver (`v2-beta`) conservée en texte |
| `catalog_missing_type.json` | valide, mais l'entrée de catalogue sans `type` est ignorée (signalée) |
| `empty_object.json` | invalide : `{}`, tous les champs obligatoires manquent |
| `array_root.json` | invalide : la racine est une liste au lieu d'un objet |

## Cas « too_large » (6 Mo)

Non committé : il est généré au moment du test par `buildOversizedManifest()`
(`package:lumio_core/testing.dart`), qui produit un manifeste syntaxiquement
valide d'environ 6 Mo. Verdict attendu : invalide `too_large` (plafond 5 Mo),
rejeté sans parser le corps entier.

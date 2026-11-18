/// Un sous-titre proposé par un addon.
class SubtitleItem {
  const SubtitleItem({
    required this.id,
    required this.url,
    required this.lang,
    required this.addonId,
  });

  final String id;
  final Uri url;

  /// Code ISO 639-1 quand il est connu, sinon la valeur brute de l'addon.
  final String lang;
  final String addonId;
}

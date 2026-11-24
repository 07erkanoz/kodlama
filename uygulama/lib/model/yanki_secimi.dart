import '../servis/ayarlar.dart';

/// Yankı modunun rolleri ve seçimleri. Ses her zaman Codex'tir; geri kalan
/// her rolün ajanı, modeli ve düşünme gücü ayrı seçilir.
class YankiSecimi {
  const YankiSecimi({
    this.ajanModel,
    this.ajanEffort,
    this.isci = 'claude',
    this.claudeModel,
    this.claudeEffort,
    this.yazili = 'codex',
    this.yaziliModel,
    this.yaziliEffort,
    this.durumNotu = 'onemli',
  });

  /// Ses ajanı: sesin işi devrettiği Codex (oturumun kendi modeli).
  final String? ajanModel, ajanEffort;

  /// Sesle istenen işi yapan: 'codex' (ses ajanı) ya da 'claude'.
  final String isci;
  final String? claudeModel, claudeEffort;

  /// Yazılı mesajları yanıtlayan: 'codex' ya da 'claude' (Codex'e uğramaz).
  final String yazili;
  final String? yaziliModel, yaziliEffort;

  /// Ses açıkken Claude'un durumunun sese bildirilmesi.
  final String durumNotu;

  static YankiSecimi varsayilan(Ayarlar a) => YankiSecimi(
    ajanModel: a.yankiCodexModel,
    ajanEffort: a.yankiCodexEffort ?? 'low',
    isci: a.yankiIsci,
    claudeModel: a.yankiClaudeModel,
    claudeEffort: a.yankiClaudeEffort,
    yazili: a.yankiYazili,
    yaziliModel: a.yankiYaziliModel,
    yaziliEffort: a.yankiYaziliEffort,
    durumNotu: a.yankiDurumNotu,
  );

  /// Bu seçimi yeni Yankı ve Asistan oturumlarının varsayılanı yap.
  void kaydet(Ayarlar a) {
    a
      ..yankiCodexModel = ajanModel
      ..yankiCodexEffort = ajanEffort
      ..yankiIsci = isci
      ..yankiClaudeModel = claudeModel
      ..yankiClaudeEffort = claudeEffort
      ..yankiYazili = yazili
      ..yankiYaziliModel = yaziliModel
      ..yankiYaziliEffort = yaziliEffort
      ..yankiDurumNotu = durumNotu;
  }

  YankiSecimi kopya({
    String? Function()? ajanModel,
    String? Function()? ajanEffort,
    String? isci,
    String? Function()? claudeModel,
    String? Function()? claudeEffort,
    String? yazili,
    String? Function()? yaziliModel,
    String? Function()? yaziliEffort,
    String? durumNotu,
  }) => YankiSecimi(
    ajanModel: ajanModel != null ? ajanModel() : this.ajanModel,
    ajanEffort: ajanEffort != null ? ajanEffort() : this.ajanEffort,
    isci: isci ?? this.isci,
    claudeModel: claudeModel != null ? claudeModel() : this.claudeModel,
    claudeEffort: claudeEffort != null ? claudeEffort() : this.claudeEffort,
    yazili: yazili ?? this.yazili,
    yaziliModel: yaziliModel != null ? yaziliModel() : this.yaziliModel,
    yaziliEffort: yaziliEffort != null ? yaziliEffort() : this.yaziliEffort,
    durumNotu: durumNotu ?? this.durumNotu,
  );

  /// Köprünün oturum_ac / yanki_ayar alanları (ses ajanının modeli hariç).
  Map<String, Object?> kopruAlanlari() => {
    'isci': isci,
    'claude_model': claudeModel ?? '',
    'claude_effort': claudeEffort ?? '',
    'yazili': yazili,
    'yazili_model': yaziliModel ?? '',
    'yazili_effort': yaziliEffort ?? '',
    'durum_notu': durumNotu,
  };

  /// Çipte görünen kısa özet.
  String get ozet =>
      'Yankı · iş ${isci == 'claude' ? 'Claude' : 'Codex'}'
      '${yazili != isci ? ' · yazı ${yazili == 'claude' ? 'Claude' : 'Codex'}' : ''}';
}

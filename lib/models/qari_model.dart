class Qari {
  final String identifier;
  final String name;
  final String englishName;
  final String format;
  final String type;

  Qari({
    required this.identifier,
    required this.name,
    required this.englishName,
    required this.format,
    required this.type,
  });

  factory Qari.fromJson(Map<String, dynamic> json) {
    return Qari(
      identifier: json['identifier'],
      name: json['name'],
      englishName: json['englishName'],
      format: json['format'],
      type: json['type'],
    );
  }
}

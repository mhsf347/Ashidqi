class SurahTable {
  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final String revelationType;

  SurahTable({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
  });

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'name': name,
      'englishName': englishName,
      'englishNameTranslation': englishNameTranslation,
      'numberOfAyahs': numberOfAyahs,
      'revelationType': revelationType,
    };
  }

  factory SurahTable.fromMap(Map<String, dynamic> map) {
    return SurahTable(
      number: map['number'],
      name: map['name'],
      englishName: map['englishName'],
      englishNameTranslation: map['englishNameTranslation'],
      numberOfAyahs: map['numberOfAyahs'],
      revelationType: map['revelationType'],
    );
  }
}

class AyahTable {
  final int? id; // Auto-increment
  final int surahNumber;
  final int number; // Number in Quran (global)
  final int numberInSurah;
  final int juz;
  final int manzil;
  final int page;
  final int ruku;
  final int hizbQuarter;
  final bool sajda;
  final String text; // Arabic
  final String textIndo; // Indonesian Translation
  final String? audio; // URL
  final String? tajweed; // Tajweed Text

  AyahTable({
    this.id,
    required this.surahNumber,
    required this.number,
    required this.numberInSurah,
    required this.juz,
    required this.manzil,
    required this.page,
    required this.ruku,
    required this.hizbQuarter,
    required this.sajda,
    required this.text,
    required this.textIndo,
    this.audio,
    this.tajweed,
  });

  Map<String, dynamic> toMap() {
    return {
      'surahNumber': surahNumber,
      'number': number,
      'numberInSurah': numberInSurah,
      'juz': juz,
      'manzil': manzil,
      'page': page,
      'ruku': ruku,
      'hizbQuarter': hizbQuarter,
      'sajda': sajda ? 1 : 0,
      'text': text,
      'textIndo': textIndo,
      'audio': audio,
      'tajweed': tajweed,
    };
  }

  factory AyahTable.fromMap(Map<String, dynamic> map) {
    return AyahTable(
      id: map['id'],
      surahNumber: map['surahNumber'],
      number: map['number'],
      numberInSurah: map['numberInSurah'],
      juz: map['juz'],
      manzil: map['manzil'],
      page: map['page'],
      ruku: map['ruku'],
      hizbQuarter: map['hizbQuarter'],
      sajda: map['sajda'] == 1,
      text: map['text'],
      textIndo: map['textIndo'],
      audio: map['audio'],
      tajweed: map['tajweed'],
    );
  }
}

class BookmarkTable {
  final int id;
  final int surahNumber;
  final int ayahNumber;
  final int timestamp;

  // Optional expanded fields from Join
  final String? surahName;
  final String? ayahText;
  final String? ayahTranslation;

  BookmarkTable({
    required this.id,
    required this.surahNumber,
    required this.ayahNumber,
    required this.timestamp,
    this.surahName,
    this.ayahText,
    this.ayahTranslation,
  });

  Map<String, dynamic> toMap() {
    return {
      'surahNumber': surahNumber,
      'ayahNumber': ayahNumber,
      'timestamp': timestamp,
    };
  }

  factory BookmarkTable.fromMap(Map<String, dynamic> map) {
    return BookmarkTable(
      id: map['id'],
      surahNumber: map['surahNumber'],
      ayahNumber: map['ayahNumber'],
      timestamp: map['timestamp'],
      surahName: map['surahName'], // From JOIN
      ayahText: map['text'], // From JOIN
      ayahTranslation: map['textIndo'], // From JOIN
    );
  }
}

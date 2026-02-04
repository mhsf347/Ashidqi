import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class DoaListScreen extends StatelessWidget {
  const DoaListScreen({super.key});

  final List<Map<String, String>> doas = const [
    {
      "title": "Doa Sebelum Makan",
      "arabic":
          "اللَّهُمَّ بَارِكْ لَنَا فِيمَا رَزَقْتَنَا وَقِنَا عَذَابَ النَّارِ",
      "translation":
          "Ya Allah, berkahilah kami dalam rezeki yang telah Engkau berikan kepada kami dan peliharalah kami dari siksa api neraka.",
    },
    {
      "title": "Doa Sesudah Makan",
      "arabic":
          "الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا وَجَعَلَنَا مُسْلِمِينَ",
      "translation":
          "Segala puji bagi Allah yang telah memberi kami makan dan minum serta menjadikan kami orang-orang muslim.",
    },
    {
      "title": "Doa Sebelum Tidur",
      "arabic": "بِسْمِكَ اللّهُمَّ أَحْيَا وَأَمُوتُ",
      "translation": "Dengan nama-Mu Ya Allah aku hidup dan aku mati.",
    },
    {
      "title": "Doa Bangun Tidur",
      "arabic":
          "الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ",
      "translation":
          "Segala puji bagi Allah, yang telah membangunkan kami setelah menidurkan kami dan kepada-Nya lah kami dibangkitkan.",
    },
    {
      "title": "Doa Masuk Masjid",
      "arabic": "اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ",
      "translation": "Ya Allah, bukalah untukku pintu-pintu rahmat-Mu.",
    },
    {
      "title": "Doa Keluar Masjid",
      "arabic": "اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ",
      "translation": "Ya Allah, sesungguhnya aku memohon keutamaan dari-Mu.",
    },
    {
      "title": "Doa Kebaikan Dunia Akhirat",
      "arabic":
          "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
      "translation":
          "Ya Tuhan kami, berilah kami kebaikan di dunia dan kebaikan di akhirat dan peliharalah kami dari siksa neraka.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF10221b)
          : const Color(0xFFF8FCFB),
      appBar: AppBar(title: const Text('Kumpulan Doa'), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: doas.length,
        itemBuilder: (context, index) {
          final doa = doas[index];
          return Card(
            color: isDark ? const Color(0xFF1a2c26) : Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              title: Text(
                doa['title']!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        doa['arabic']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 24,
                          height: 1.8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        doa['translation']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ContributorScreen extends StatelessWidget {
  const ContributorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final contributors = [
      {'name': 'MHSF', 'role': 'Lead Developer', 'initial': 'M'},
    ];

    final apis = [
      {
        'name': 'Al-Quran Cloud API',
        'desc': 'Data Al-Quran & Audio',
        'initial': 'Q',
      },
      {
        'name': 'Doa-Doa API',
        'desc': 'doa-doa-api-ahmadramadhan',
        'initial': 'D',
      },
      {
        'name': 'Hadith API',
        'desc': 'hadith-api-go.vercel.app',
        'initial': 'H',
      },
      {
        'name': 'Overpass API & OSM',
        'desc': 'Data Lokasi Masjid',
        'initial': 'O',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontributor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Pengembang'),
            const SizedBox(height: 12),
            ...contributors.map(
              (c) => _buildContributorCard(context, isDark, c),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle(context, 'API & Sumber Data Open Source'),
            const SizedBox(height: 12),
            ...apis.map(
              (a) => _buildContributorCard(context, isDark, a, isApi: true),
            ),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Terima kasih kepada komunitas Open Source yang telah menyediakan API dan data yang memungkinkan aplikasi ini berjalan.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildContributorCard(
    BuildContext context,
    bool isDark,
    Map<String, String> data, {
    bool isApi = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isApi
                ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100)
                : AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              data['initial']!,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isApi
                    ? (isDark ? Colors.grey.shade400 : Colors.grey.shade600)
                    : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name']!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (data['role'] != null)
                  Text(
                    data['role']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade500,
                    ),
                  ),
                if (data['desc'] != null)
                  Text(
                    data['desc']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

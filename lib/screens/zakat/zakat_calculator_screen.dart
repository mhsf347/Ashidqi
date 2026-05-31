import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';

/// Zakat Calculator Screen
/// Supports: Zakat Maal, Penghasilan, Emas, Fitrah
class ZakatCalculatorScreen extends StatefulWidget {
  const ZakatCalculatorScreen({super.key});

  @override
  State<ZakatCalculatorScreen> createState() => _ZakatCalculatorScreenState();
}

enum ZakatType { maal, penghasilan, emas, fitrah }

class _ZakatCalculatorScreenState extends State<ZakatCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Zakat Maal
  final _hartaController = TextEditingController();
  final _hutangController = TextEditingController();

  // Zakat Penghasilan
  final _gajiController = TextEditingController();
  final _pengeluaranController = TextEditingController();

  // Zakat Emas
  final _beratEmasController = TextEditingController();
  final _hargaEmasController = TextEditingController(text: '1350000');

  // Zakat Fitrah
  final _jumlahJiwaController = TextEditingController(text: '1');
  final _hargaBerasController = TextEditingController(text: '15000');

  // Nisab Emas (85 gram)
  static const double nisabEmasGram = 85.0;

  // Results
  double? _result;
  String _resultLabel = '';
  bool _isNisabMet = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _result = null;
        _resultLabel = '';
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hartaController.dispose();
    _hutangController.dispose();
    _gajiController.dispose();
    _pengeluaranController.dispose();
    _beratEmasController.dispose();
    _hargaEmasController.dispose();
    _jumlahJiwaController.dispose();
    _hargaBerasController.dispose();
    super.dispose();
  }

  double _parseInput(TextEditingController ctrl) {
    final text = ctrl.text.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(text) ?? 0.0;
  }

  void _calculateMaal() {
    final harta = _parseInput(_hartaController);
    final hutang = _parseInput(_hutangController);
    final hargaEmas = _parseInput(_hargaEmasController);
    final nisab = nisabEmasGram * hargaEmas;
    final netHarta = harta - hutang;

    setState(() {
      if (netHarta >= nisab) {
        _result = netHarta * 0.025;
        _isNisabMet = true;
        _resultLabel = 'Zakat Maal (2.5% × Rp ${_formatCurrency(netHarta)})';
      } else {
        _result = 0;
        _isNisabMet = false;
        _resultLabel =
            'Harta bersih (Rp ${_formatCurrency(netHarta)}) belum mencapai nisab (Rp ${_formatCurrency(nisab)})';
      }
    });
  }

  void _calculatePenghasilan() {
    final gaji = _parseInput(_gajiController);
    final pengeluaran = _parseInput(_pengeluaranController);
    final penghasilanBersih = gaji - pengeluaran;

    setState(() {
      if (penghasilanBersih > 0) {
        _result = penghasilanBersih * 0.025;
        _isNisabMet = true;
        _resultLabel =
            'Zakat Penghasilan Bulanan (2.5% × Rp ${_formatCurrency(penghasilanBersih)})';
      } else {
        _result = 0;
        _isNisabMet = false;
        _resultLabel = 'Penghasilan bersih harus lebih dari 0';
      }
    });
  }

  void _calculateEmas() {
    final berat = _parseInput(_beratEmasController);
    final hargaPerGram = _parseInput(_hargaEmasController);

    setState(() {
      if (berat >= nisabEmasGram) {
        _result = berat * hargaPerGram * 0.025;
        _isNisabMet = true;
        _resultLabel =
            'Zakat Emas (2.5% × ${berat.toStringAsFixed(1)}g × Rp ${_formatCurrency(hargaPerGram)})';
      } else {
        _result = 0;
        _isNisabMet = false;
        _resultLabel =
            'Berat emas (${berat.toStringAsFixed(1)}g) belum mencapai nisab (${nisabEmasGram}g)';
      }
    });
  }

  void _calculateFitrah() {
    final jiwa = _parseInput(_jumlahJiwaController).round();
    final hargaBeras = _parseInput(_hargaBerasController);
    // 2.5 kg beras per jiwa (standar)
    const beratPerJiwa = 2.5;

    setState(() {
      _result = jiwa * beratPerJiwa * hargaBeras;
      _isNisabMet = true;
      _resultLabel =
          'Zakat Fitrah ($jiwa jiwa × ${beratPerJiwa}kg × Rp ${_formatCurrency(hargaBeras)})';
    });
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)} M';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} Jt';
    }
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  String _formatFullCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF10221b) : const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Kalkulator Zakat'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'Maal'),
            Tab(text: 'Penghasilan'),
            Tab(text: 'Emas'),
            Tab(text: 'Fitrah'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMaalTab(isDark),
          _buildPenghasilanTab(isDark),
          _buildEmasTab(isDark),
          _buildFitrahTab(isDark),
        ],
      ),
    );
  }

  Widget _buildMaalTab(bool isDark) {
    return _buildTabContent(
      isDark: isDark,
      icon: Icons.account_balance_wallet_outlined,
      title: 'Zakat Maal',
      description:
          'Zakat atas harta yang dimiliki (tabungan, investasi, dll) selama setahun. Wajib jika harta bersih ≥ nisab (85 gram emas).',
      fields: [
        _buildInputField(
          controller: _hartaController,
          label: 'Total Harta (Rp)',
          hint: 'Contoh: 100000000',
          icon: Icons.savings_outlined,
          isDark: isDark,
        ),
        _buildInputField(
          controller: _hutangController,
          label: 'Total Hutang (Rp)',
          hint: 'Contoh: 5000000',
          icon: Icons.money_off_outlined,
          isDark: isDark,
        ),
        _buildInputField(
          controller: _hargaEmasController,
          label: 'Harga Emas/gram (Rp)',
          hint: 'Harga emas terkini',
          icon: Icons.diamond_outlined,
          isDark: isDark,
        ),
      ],
      onCalculate: _calculateMaal,
    );
  }

  Widget _buildPenghasilanTab(bool isDark) {
    return _buildTabContent(
      isDark: isDark,
      icon: Icons.work_outline,
      title: 'Zakat Penghasilan',
      description:
          'Zakat 2.5% dari penghasilan bersih bulanan (gaji dikurangi kebutuhan pokok).',
      fields: [
        _buildInputField(
          controller: _gajiController,
          label: 'Gaji per Bulan (Rp)',
          hint: 'Contoh: 10000000',
          icon: Icons.payments_outlined,
          isDark: isDark,
        ),
        _buildInputField(
          controller: _pengeluaranController,
          label: 'Kebutuhan Pokok (Rp)',
          hint: 'Contoh: 3000000',
          icon: Icons.receipt_long_outlined,
          isDark: isDark,
        ),
      ],
      onCalculate: _calculatePenghasilan,
    );
  }

  Widget _buildEmasTab(bool isDark) {
    return _buildTabContent(
      isDark: isDark,
      icon: Icons.diamond_outlined,
      title: 'Zakat Emas',
      description:
          'Zakat 2.5% atas kepemilikan emas yang mencapai nisab (85 gram).',
      fields: [
        _buildInputField(
          controller: _beratEmasController,
          label: 'Berat Emas (gram)',
          hint: 'Contoh: 100',
          icon: Icons.scale_outlined,
          isDark: isDark,
        ),
        _buildInputField(
          controller: _hargaEmasController,
          label: 'Harga Emas/gram (Rp)',
          hint: 'Harga emas terkini',
          icon: Icons.diamond_outlined,
          isDark: isDark,
        ),
      ],
      onCalculate: _calculateEmas,
    );
  }

  Widget _buildFitrahTab(bool isDark) {
    return _buildTabContent(
      isDark: isDark,
      icon: Icons.people_outline,
      title: 'Zakat Fitrah',
      description:
          'Zakat wajib di bulan Ramadhan, sebesar 2.5 kg beras (atau makanan pokok) per jiwa.',
      fields: [
        _buildInputField(
          controller: _jumlahJiwaController,
          label: 'Jumlah Jiwa',
          hint: 'Anggota keluarga',
          icon: Icons.family_restroom_outlined,
          isDark: isDark,
        ),
        _buildInputField(
          controller: _hargaBerasController,
          label: 'Harga Beras/kg (Rp)',
          hint: 'Contoh: 15000',
          icon: Icons.rice_bowl_outlined,
          isDark: isDark,
        ),
      ],
      onCalculate: _calculateFitrah,
    );
  }

  Widget _buildTabContent({
    required bool isDark,
    required IconData icon,
    required String title,
    required String description,
    required List<Widget> fields,
    required VoidCallback onCalculate,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 24),

          // Input Fields
          ...fields.map((field) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: field,
              )),

          const SizedBox(height: 8),

          // Calculate Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onCalculate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Hitung Zakat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),

          const SizedBox(height: 24),

          // Result Card
          if (_result != null) _buildResultCard(isDark),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2e26) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        ],
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05, end: 0);
  }

  Widget _buildResultCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _isNisabMet
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
              )
            : null,
        color: _isNisabMet ? null : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isNisabMet
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _isNisabMet ? Icons.check_circle_outline : Icons.info_outline,
            color: _isNisabMet ? AppColors.primary : Colors.orange,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            _isNisabMet ? 'Zakat yang Harus Dibayar' : 'Belum Wajib Zakat',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          if (_isNisabMet)
            Text(
              'Rp ${_formatFullCurrency(_result!)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            _resultLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          if (_isNisabMet) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildResultAction(
                  icon: Icons.copy,
                  label: 'Salin',
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                      text:
                          '$_resultLabel\nJumlah: Rp ${_formatFullCurrency(_result!)}',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hasil zakat disalin!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 24),
                _buildResultAction(
                  icon: Icons.share,
                  label: 'Bagikan',
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                      text:
                          '🕌 Kalkulator Zakat Ashidqi\n$_resultLabel\nJumlah: Rp ${_formatFullCurrency(_result!)}',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hasil disalin, siap dibagikan!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildResultAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

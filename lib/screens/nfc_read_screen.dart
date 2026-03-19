import 'package:flutter/material.dart';
import '../services/nfc_service.dart';
import '../theme/colors.dart';

/// NFC読み取り画面
class NfcReadScreen extends StatefulWidget {
  const NfcReadScreen({super.key});

  @override
  State<NfcReadScreen> createState() => _NfcReadScreenState();
}

enum _NfcReadState {
  idle,
  scanning,
  success,
  error,
}

class _NfcReadScreenState extends State<NfcReadScreen>
    with SingleTickerProviderStateMixin {
  _NfcReadState _state = _NfcReadState.idle;
  String _readText = '';
  String _errorMessage = '';
  bool _isUchinokoData = false;
  bool _nfcAvailable = true;

  late AnimationController _successAnimController;
  late Animation<double> _successScaleAnim;

  @override
  void initState() {
    super.initState();
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimController,
        curve: Curves.elasticOut,
      ),
    );
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    _successAnimController.dispose();
    NfcService.instance.stopSession();
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    final available = await NfcService.instance.isAvailable();
    if (mounted) {
      setState(() => _nfcAvailable = available);
    }
  }

  Future<void> _startRead() async {
    setState(() => _state = _NfcReadState.scanning);

    final response = await NfcService.instance.readTag();

    if (!mounted) return;

    switch (response.result) {
      case NfcReadResult.success:
        setState(() {
          _state = _NfcReadState.success;
          _readText = response.text ?? '';
          _isUchinokoData = true;
        });
        _successAnimController.forward();
      case NfcReadResult.notUchinokoData:
        setState(() {
          _state = _NfcReadState.success;
          _readText = response.text ?? '';
          _isUchinokoData = false;
        });
        _successAnimController.forward();
      case NfcReadResult.notAvailable:
        setState(() {
          _state = _NfcReadState.error;
          _errorMessage = 'お使いの端末はNFCに対応していません';
        });
      case NfcReadResult.noNdef:
        setState(() {
          _state = _NfcReadState.error;
          _errorMessage = 'このタグにはデータがありません'
              '${response.errorDetail != null ? '\n${response.errorDetail}' : ''}';
        });
      case NfcReadResult.timeout:
        setState(() {
          _state = _NfcReadState.error;
          _errorMessage = 'タイムアウトしました。もう一度お試しください';
        });
      case NfcReadResult.readFailed:
        setState(() {
          _state = _NfcReadState.error;
          _errorMessage = '読み取りに失敗しました'
              '${response.errorDetail != null ? '\n\n[詳細] ${response.errorDetail}' : ''}';
        });
    }
  }

  void _reset() {
    _successAnimController.reset();
    setState(() {
      _state = _NfcReadState.idle;
      _readText = '';
      _errorMessage = '';
      _isUchinokoData = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('NFCを読み取る'),
        elevation: 0,
        leading: _state == _NfcReadState.scanning
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: SafeArea(
        child: switch (_state) {
          _NfcReadState.idle => _buildIdleView(),
          _NfcReadState.scanning => _buildScanningView(),
          _NfcReadState.success => _buildSuccessView(),
          _NfcReadState.error => _buildErrorView(),
        },
      ),
    );
  }

  Widget _buildIdleView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.nfc,
                size: 60,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'NFCタグの内容を確認',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'タグに書き込まれたペット情報を\n読み取って表示します',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMedium,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '読み取った情報は保存されません',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 220,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _nfcAvailable ? _startRead : null,
                icon: const Icon(Icons.contactless, size: 22),
                label: Text(
                  _nfcAvailable ? '読み取り開始' : 'NFCに対応していません',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation(AppColors.secondary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '読み取り中...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'iOSのNFCダイアログでタグをかざしてください',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 40),
          TextButton(
            onPressed: () {
              NfcService.instance.stopSession();
              _reset();
            },
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          ScaleTransition(
            scale: _successScaleAnim,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.check_circle,
                size: 48,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '読み取り完了',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          if (!_isUchinokoData) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'うちの子免許証のデータではありません',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // 読み取りデータ表示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isUchinokoData
                    ? AppColors.secondary.withValues(alpha: 0.3)
                    : Colors.grey.shade300,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isUchinokoData ? Icons.pets : Icons.description,
                      size: 20,
                      color: _isUchinokoData
                          ? AppColors.secondary
                          : AppColors.textMedium,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isUchinokoData ? 'ペット情報' : 'タグの内容',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _readText,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ボタン
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('もう一度読む'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('閉じる',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 60,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '読み取りに失敗しました',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMedium,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              height: 48,
              child: ElevatedButton(
                onPressed: _reset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('もう一度試す',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

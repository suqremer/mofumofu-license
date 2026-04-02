import 'package:flutter/material.dart';
import '../models/license_card.dart';
import '../services/nfc_service.dart';
import '../theme/colors.dart';

/// NFC書き込み画面
///
/// 免許証のペット情報をNFCタグに書き込む。
/// 飼い主名・電話番号・特記事項はユーザーが入力/編集できる。
class NfcWriteScreen extends StatefulWidget {
  final LicenseCard card;

  const NfcWriteScreen({super.key, required this.card});

  @override
  State<NfcWriteScreen> createState() => _NfcWriteScreenState();
}

enum _NfcWriteState {
  editing, // 情報入力中
  waiting, // NFC待機中
  writing, // 書き込み中
  success, // 成功
  error, // 失敗
}

class _NfcWriteScreenState extends State<NfcWriteScreen>
    with SingleTickerProviderStateMixin {
  final _ownerController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _NfcWriteState _state = _NfcWriteState.editing;
  String _errorMessage = '';
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
    _ownerController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
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

  String _buildPreviewText() {
    return NfcService.buildNfcText(
      petName: widget.card.petName,
      breed: widget.card.breed ?? widget.card.species,
      ownerName: _ownerController.text,
      phoneNumber: _phoneController.text,
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );
  }

  int _currentBytes() {
    return NfcService.calculateBytes(_buildPreviewText());
  }

  Future<void> _startWrite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _state = _NfcWriteState.waiting);

    final text = _buildPreviewText();
    final response = await NfcService.instance.writeText(
      text: text,
      onTagDiscovered: () {
        if (mounted) {
          setState(() => _state = _NfcWriteState.writing);
        }
      },
    );

    if (!mounted) return;

    switch (response.result) {
      case NfcWriteResult.success:
        setState(() => _state = _NfcWriteState.success);
        _successAnimController.forward();
      case NfcWriteResult.notAvailable:
        setState(() {
          _state = _NfcWriteState.error;
          _errorMessage = 'お使いの端末はNFCに対応していません';
        });
      case NfcWriteResult.capacityExceeded:
        setState(() {
          _state = _NfcWriteState.error;
          _errorMessage = 'データが大きすぎます。特記事項を短くしてください';
        });
      case NfcWriteResult.timeout:
        setState(() {
          _state = _NfcWriteState.error;
          _errorMessage = 'タイムアウトしました。もう一度お試しください';
        });
      case NfcWriteResult.tagNotFound:
      case NfcWriteResult.writeFailed:
        setState(() {
          _state = _NfcWriteState.error;
          _errorMessage = '書き込みに失敗しました。カードを確認してもう一度お試しください'
              '${response.errorDetail != null ? '\n\n[詳細] ${response.errorDetail}' : ''}';
        });
    }
  }

  void _retry() {
    setState(() {
      _state = _NfcWriteState.editing;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('NFCに書き込む'),
        elevation: 0,
        leading: _state == _NfcWriteState.waiting ||
                _state == _NfcWriteState.writing
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: SafeArea(
        child: switch (_state) {
          _NfcWriteState.editing => _buildEditForm(),
          _NfcWriteState.waiting => _buildWaitingView(),
          _NfcWriteState.writing => _buildWritingView(),
          _NfcWriteState.success => _buildSuccessView(),
          _NfcWriteState.error => _buildErrorView(),
        },
      ),
    );
  }

  /// 情報入力フォーム
  Widget _buildEditForm() {
    final bytes = _currentBytes();
    final isOverCapacity = bytes > NfcService.maxCapacity;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 説明
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppColors.secondary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'NFCカードにペットの迷子情報を書き込みます。\nデータはサーバーに送信されません。',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ペット情報（自動入力・読み取り専用）
            _buildSectionHeader('ペット情報'),
            const SizedBox(height: 8),
            _buildReadOnlyField('ペット名', widget.card.petName),
            const SizedBox(height: 8),
            _buildReadOnlyField(
                '品種', widget.card.breed ?? widget.card.species),
            const SizedBox(height: 20),

            // 飼い主情報（入力可能）
            _buildSectionHeader('飼い主情報'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ownerController,
              decoration: _inputDecoration('飼い主名', '例: 山田太郎'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '飼い主名を入力してください' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: _inputDecoration('電話番号', '例: 090-1234-5678'),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '電話番号を入力してください' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: _inputDecoration('特記事項（任意）', '例: 卵アレルギーあり'),
              maxLines: 2,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // バイト数表示
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'データサイズ: $bytes / ${NfcService.maxCapacity} バイト',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverCapacity ? AppColors.error : AppColors.textMedium,
                    fontWeight:
                        isOverCapacity ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (bytes / NfcService.maxCapacity).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                isOverCapacity ? AppColors.error : AppColors.secondary,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 24),

            // プレビュー
            if (_ownerController.text.isNotEmpty &&
                _phoneController.text.isNotEmpty) ...[
              _buildSectionHeader('書き込み内容プレビュー'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  _buildPreviewText(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 書き込みボタン
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    _nfcAvailable && !isOverCapacity ? _startWrite : null,
                icon: const Icon(Icons.nfc, size: 22),
                label: Text(
                  _nfcAvailable ? '書き込み開始' : 'NFCに対応していません',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

            if (!_nfcAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'この端末はNFCに対応していないため、書き込みできません。',
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// NFC待機中の表示
  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // NFCアイコンアニメーション
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.2),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            onEnd: () {
              // ループさせる（rebuilder的にここで再描画）
            },
            child: Container(
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
          ),
          const SizedBox(height: 32),
          Text(
            'NFCカードにスマホをかざしてください',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'カードの裏面にスマホの背面を\nぴったり当ててください',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          TextButton(
            onPressed: () {
              NfcService.instance.stopSession();
              _retry();
            },
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  /// 書き込み中の表示
  Widget _buildWritingView() {
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
            '書き込み中...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'カードを離さないでください',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 40),
          TextButton(
            onPressed: () {
              NfcService.instance.stopSession();
              _retry();
            },
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  /// 成功表示
  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _successScaleAnim,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.check_circle,
                size: 60,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '書き込み完了！',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'NFCカードにペット情報を書き込みました',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('閉じる',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  /// エラー表示
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
              '書き込みに失敗しました',
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
                onPressed: _retry,
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.secondary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

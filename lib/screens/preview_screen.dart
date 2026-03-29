import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/license_card.dart';
import '../models/costume_overlay.dart';
import '../models/pet.dart';
import '../providers/database_provider.dart';
import '../services/ad_manager.dart';
import '../services/app_preferences.dart';
import '../services/database_service.dart';
import '../services/purchase_manager.dart';
import '../services/license_composer.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/paywall_bottom_sheet.dart';

/// 画面5: 完成プレビュー+カメラロール保存+シェア
///
/// 合成完了時にアプリ内DB保存は自動実行。
/// ユーザーは「カメラロールに保存」「シェア」「もう1枚」を即座に選べる。
class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen>
    with TickerProviderStateMixin {
  Uint8List? _composedImage;
  Uint8List? _composedImageHiRes;
  LicenseComposeRequest? _lastRequest; // 写真プレビュー生成用
  bool _isComposing = false;
  bool _isSavingToGallery = false;
  bool _isSharing = false;
  String? _error;
  Map<String, dynamic>? _data;
  bool _dataLoaded = false;

  /// 自動保存（DB）が完了したか
  bool _autoSaved = false;

  /// カメラロールに保存済みか
  bool _savedToGallery = false;

  /// フラッシュアニメーション
  late final AnimationController _flashController;
  late final Animation<double> _flashOpacity;
  bool _flashTriggered = false;

  /// スライドインアニメーション（免許証が窓口から出てくる）
  late final AnimationController _slideController;
  late final Animation<double> _slideOffset;
  late final Animation<double> _slideOpacity;

  /// 印鑑スタンプアニメーション
  late final AnimationController _stampController;
  late final Animation<double> _stampScale;
  late final Animation<double> _stampRotation;
  late final Animation<double> _stampOpacity;

  /// 効果音
  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    // フラッシュ
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flashOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

    // スライドイン（下から上へ）
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideOffset = Tween<double>(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _slideOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // 印鑑スタンプ（回転+バウンス）
    _stampController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _stampScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 3.0, end: 0.9), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _stampController,
      curve: Curves.easeOut,
    ));
    _stampRotation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(parent: _stampController, curve: Curves.easeOutBack),
    );
    _stampOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _stampController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // インタースティシャル広告を事前ロード
    AdManager.instance.preloadInterstitial();
  }

  @override
  void dispose() {
    _flashController.dispose();
    _slideController.dispose();
    _stampController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 毎回extraからデータを読み直す（State再利用時の古いデータ残留を防止）
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic> && extra != _data) {
      _data = extra;
      _composedImage = null;
      _composedImageHiRes = null;
      _autoSaved = false;
      _savedToGallery = false;
      _flashTriggered = false;
      _error = null;
      _startCompose();
    } else if (!_dataLoaded && extra is! Map<String, dynamic>) {
      _dataLoaded = true;
      setState(() => _error = 'データの受け渡しに失敗しました');
    }
  }

  Future<void> _startCompose() async {
    if (_isComposing || _data == null) return;
    setState(() {
      _isComposing = true;
      _error = null;
    });

    try {
      final data = _data!;
      final photoPath = data['photoPath'] as String?;
      if (photoPath == null || photoPath.isEmpty) {
        throw Exception('写真データがありません');
      }

      final photoBytes = await File(photoPath).readAsBytes();

      final overlayMaps = data['costumeOverlays'] as List<dynamic>? ?? [];
      final costumeOverlays = overlayMaps
          .map((m) => CostumeOverlay.fromMap(m as Map<String, dynamic>))
          .toList();

      final request = LicenseComposeRequest(
        petName: data['petName'] as String,
        species: data['species'] as String,
        breed: (data['breed'] as String?)?.isNotEmpty == true
            ? data['breed'] as String
            : null,
        birthDate: data['birthDate'] != null
            ? DateTime.parse(data['birthDate'] as String)
            : null,
        birthDateUnknown: data['birthDateUnknown'] as bool? ?? false,
        gender: data['gender'] as String?,
        specialty: (data['specialty'] as String?)?.isNotEmpty == true
            ? data['specialty'] as String
            : null,
        specialtyId: data['specialtyId'] as String?,
        customCondition:
            (data['customCondition'] as String?)?.isNotEmpty == true
                ? data['customCondition'] as String
                : null,
        customAddress:
            (data['customAddress'] as String?)?.isNotEmpty == true
                ? data['customAddress'] as String
                : null,
        licenseType: data['licenseType'] as String,
        photoBytes: photoBytes,
        costumeId: data['costumeId'] as String,
        frameColor: data['frameColor'] as String,
        templateType: data['templateType'] as String? ?? 'japan',
        validityId: data['validityId'] as String? ?? 'nap',
        costumeOverlays: costumeOverlays,
        photoScale: (data['photoScale'] as num?)?.toDouble() ?? 1.0,
        photoOffsetX: (data['photoOffsetX'] as num?)?.toDouble() ?? 0.0,
        photoOffsetY: (data['photoOffsetY'] as num?)?.toDouble() ?? 0.0,
        photoRotation: (data['photoRotation'] as num?)?.toDouble() ?? 0.0,
        outfitId: data['outfitId'] as String?,
        photoBgColor: data['photoBgColor'] as int?,
        photoBrightness: (data['photoBrightness'] as num?)?.toDouble() ?? 0.0,
        photoContrast: (data['photoContrast'] as num?)?.toDouble() ?? 0.0,
        photoSaturation: (data['photoSaturation'] as num?)?.toDouble() ?? 0.0,
      );

      _lastRequest = request; // 写真プレビュー生成用に保存
      // プレビュー表示は1xで合成（USAテンプレのギョーシェ描画が2xだとメモリ不足になるため）
      final imageBytes = await LicenseComposer().compose(request, scale: 1.0);

      if (!mounted) return;
      setState(() {
        _composedImage = imageBytes;
        _isComposing = false;
      });

      // フラッシュ + SE + バイブ演出
      _playShutterEffect();

      // 高解像度版を非同期で合成してDB保存
      final hiResBytes = await LicenseComposer().compose(request, scale: 2.0);
      _composedImageHiRes = hiResBytes;

      // 合成完了 → 自動でアプリ内DBに保存（高解像度版を使用）
      await _autoSaveToDB();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '免許証の生成に失敗しました。もう一度試してね';
        _isComposing = false;
      });
    }
  }

  /// 交付演出チェーン: スライドイン → フラッシュ+SE → 印鑑スタンプ
  Future<void> _playShutterEffect() async {
    if (_flashTriggered) return;
    setState(() => _flashTriggered = true);

    // 1. 免許証スライドイン（窓口から出てくる演出）
    _slideController.forward(from: 0.0);
    await Future.delayed(const Duration(milliseconds: 500));

    // 2. フラッシュ + バイブ + SE
    _flashController.forward(from: 0.0);
    HapticFeedback.heavyImpact();
    try {
      await _audioPlayer.play(AssetSource('sounds/dog_bark.mp3'));
    } catch (_) {
      // 音声再生失敗は無視
    }

    // 3. 印鑑スタンプ（ポンッ）
    await Future.delayed(const Duration(milliseconds: 300));
    _stampController.forward(from: 0.0);
    // スタンプ着地時に軽いバイブ
    await Future.delayed(const Duration(milliseconds: 360));
    HapticFeedback.mediumImpact();
  }

  /// 合成完了時に自動でアプリ内DBに保存（編集時はupdate）
  Future<void> _autoSaveToDB() async {
    if (_composedImage == null || _autoSaved || _data == null) return;

    try {
      // 高解像度版があればそちらを保存、なければ通常版
      final imageToSave = _composedImageHiRes ?? _composedImage!;
      final savedPath = await LicenseComposer().saveToFile(imageToSave);

      // 写真プレビュー画像も生成・保存（ホーム画面表示用）
      if (_lastRequest != null) {
        try {
          final photoPreviewBytes =
              await LicenseComposer().composePhotoPreview(_lastRequest!);
          final photoPreviewPath =
              savedPath.replaceAll('.png', '_photo.png');
          await File(photoPreviewPath).writeAsBytes(photoPreviewBytes);
        } catch (_) {
          // 写真プレビュー生成失敗は免許証保存をブロックしない
        }
      }
      final data = _data!;
      final now = DateTime.now();
      final editId = data['editId'] as int?;

      // コスチューム配置・写真調整等をJSON化して保存
      final extraDataMap = <String, dynamic>{
        if (data['costumeOverlays'] != null)
          'costumeOverlays': data['costumeOverlays'],
        if (data['photoBgColor'] != null)
          'photoBgColor': data['photoBgColor'],
        if (data['photoScale'] != null)
          'photoScale': data['photoScale'],
        if (data['photoOffsetX'] != null)
          'photoOffsetX': data['photoOffsetX'],
        if (data['photoOffsetY'] != null)
          'photoOffsetY': data['photoOffsetY'],
        if (data['photoRotation'] != null && data['photoRotation'] != 0.0)
          'photoRotation': data['photoRotation'],
        if (data['outfitId'] != null)
          'outfitId': data['outfitId'],
        if (data['validityId'] != null)
          'validityId': data['validityId'],
        if (data['photoBrightness'] != null && data['photoBrightness'] != 0.0)
          'photoBrightness': data['photoBrightness'],
        if (data['photoContrast'] != null && data['photoContrast'] != 0.0)
          'photoContrast': data['photoContrast'],
        if (data['photoSaturation'] != null && data['photoSaturation'] != 0.0)
          'photoSaturation': data['photoSaturation'],
        if (data['originalPhotoPath'] != null)
          'originalPhotoPath': data['originalPhotoPath'],
      };

      final card = LicenseCard(
        id: editId,
        petName: data['petName'] as String,
        species: data['species'] as String,
        breed: (data['breed'] as String?)?.isNotEmpty == true
            ? data['breed'] as String
            : null,
        birthDate: data['birthDate'] != null
            ? DateTime.parse(data['birthDate'] as String)
            : null,
        gender: data['gender'] as String?,
        specialty: (data['specialty'] as String?)?.isNotEmpty == true
            ? data['specialty'] as String
            : null,
        licenseType: data['licenseType'] as String,
        photoPath: data['photoPath'] as String,
        costumeId: data['costumeId'] as String,
        frameColor: data['frameColor'] as String,
        templateType: data['templateType'] as String? ?? 'japan',
        savedImagePath: savedPath,
        extraData: extraDataMap.isNotEmpty ? extraDataMap : null,
        createdAt:
            editId != null ? (data['createdAt'] as DateTime? ?? now) : now,
        updatedAt: now,
      );

      if (editId != null) {
        await DatabaseService().updateLicense(card);
      } else {
        final newId = await DatabaseService().insertLicense(card);
        // 再合成時に重複insertされないよう、editIdをセット
        _data!['editId'] = newId;
        // 新規作成のみ作成数をインクリメント（ローカル+RevenueCatサーバー）
        await PurchaseManager.instance.incrementCreationCount();

        // ペット手帳に未登録なら自動登録
        await _registerPetIfNew(card);
      }
      // ドラフトをクリア
      await AppPreferences.clearDraft();

      ref.invalidate(licensesProvider);
      ref.invalidate(licenseCountProvider);
      ref.invalidate(petsProvider);

      if (!mounted) return;
      setState(() => _autoSaved = true);

      // インタースティシャル広告を表示（無料ユーザーのみ）
      AdManager.instance.showInterstitial();
    } catch (e) {
      // 自動保存失敗は致命的ではない — エラーだけ表示
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('自動保存に失敗しました。もう一度試してね'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// 同名+同種のペットが未登録ならペット手帳に自動登録
  Future<void> _registerPetIfNew(LicenseCard card) async {
    try {
      final existing = await DatabaseService()
          .findPetByNameAndSpecies(card.petName, card.species);
      if (existing != null) return; // 既に登録済み

      final now = DateTime.now();
      final pet = Pet(
        name: card.petName,
        species: card.species,
        breed: card.breed,
        birthDate: card.birthDate,
        gender: card.gender,
        photoPath: card.photoPath,
        createdAt: now,
        updatedAt: now,
      );
      await DatabaseService().insertPet(pet);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ペット手帳にも登録しました！'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // ペット手帳登録失敗は致命的ではない — 無視
    }
  }

  /// カメラロールに保存
  Future<void> _saveToGallery() async {
    if (_composedImage == null || _isSavingToGallery) return;
    setState(() => _isSavingToGallery = true);

    try {
      // 権限チェック
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      // 高解像度版があればそちらをカメラロールに保存
      final imageToSave = _composedImageHiRes ?? _composedImage!;
      await Gal.putImageBytes(imageToSave,
          name:
              'mofumofu_license_${DateTime.now().millisecondsSinceEpoch}.png');

      if (!mounted) return;
      setState(() {
        _isSavingToGallery = false;
        _savedToGallery = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('カメラロールに保存しました！'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } on GalException catch (e) {
      if (!mounted) return;
      setState(() => _isSavingToGallery = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('カメラロールへの保存に失敗しました: ${_galErrorMessage(e)}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _shareImage() async {
    if (_composedImage == null || _isSharing) return;
    setState(() => _isSharing = true);

    try {
      // 高解像度版があればそちらでシェア画像を生成
      final sourceImage = _composedImageHiRes ?? _composedImage!;
      final shareBytes =
          await LicenseComposer().composeShareImage(sourceImage);
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile =
          File('${tempDir.path}/mofumofu_license_$timestamp.png');
      await tempFile.writeAsBytes(shareBytes);

      if (!mounted) return;
      setState(() => _isSharing = false);

      // iPad対応: sharePositionOriginを指定しないとクラッシュする場合がある
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'うちの子免許証で免許証を発行したよ！',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      debugPrint('Share error: $e');
      if (!mounted) return;
      setState(() => _isSharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('シェアに失敗しました: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// もう1枚つくる（月間上限チェック付き）
  void _createAnother() {
    if (!AppPreferences.canCreateLicense) {
      PaywallBottomSheet.show(context);
      return;
    }
    AppPreferences.clearDraft();
    // go_routerが同じpathのページStateを再利用する問題を回避:
    // 1) ホームに戻って古いcreateフロー全画面をスタックから破棄
    // 2) 1フレーム待ってから新しいPhotoSelectScreenをpush
    final goRouter = GoRouter.of(context);
    goRouter.go('/');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      goRouter.push('/create/photo');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('交付完了'),
        leading: IconButton(
          onPressed: () => context.pop(_data?['editId'] as int?),
          icon: const Icon(Icons.arrow_back),
          tooltip: '戻る',
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined),
            tooltip: 'ホームに戻る',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _buildBody(),
            // フラッシュオーバーレイ
            if (_flashTriggered)
              AnimatedBuilder(
                animation: _flashOpacity,
                builder: (context, child) => IgnorePointer(
                  child: Container(
                    color: Colors.white
                        .withValues(alpha: _flashOpacity.value),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          _buildPreviewArea(),
          const SizedBox(height: AppSpacing.lg),
          _buildCongratulationMessage(),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    // 合成中はプログレスを表示（スライドなし）
    if (_isComposing || (_composedImage == null && _error == null)) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 1.586,
          child: _buildPreviewContent(),
        ),
      );
    }

    // 完成後はスライドインアニメーション付きで表示
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _slideOffset.value),
        child: Opacity(
          opacity: _slideController.isAnimating || _slideController.isCompleted
              ? _slideOpacity.value
              : 0.0,
          child: child,
        ),
      ),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 1.586,
              child: _buildPreviewContent(),
            ),
          ),
          // 印鑑スタンプオーバーレイ
          _buildStampOverlay(),
        ],
      ),
    );
  }

  /// 印鑑スタンプ（回転しながらポンッと着地）
  Widget _buildStampOverlay() {
    return AnimatedBuilder(
      animation: _stampController,
      builder: (context, child) {
        if (!_stampController.isAnimating && !_stampController.isCompleted) {
          return const SizedBox.shrink();
        }
        return Positioned(
          right: 16,
          bottom: 16,
          child: Opacity(
            opacity: _stampOpacity.value,
            child: Transform.scale(
              scale: _stampScale.value,
              child: Transform.rotate(
                angle: _stampRotation.value,
                child: child,
              ),
            ),
          ),
        );
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.licenseSealRed, width: 3),
        ),
        child: Center(
          child: Text(
            '交\n付',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.licenseSealRed,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    if (_error != null) {
      return Container(
        color: AppColors.surfaceVariant,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: AppSpacing.md),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 14)),
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: _startCompose,
                  icon: const Icon(Icons.refresh),
                  label: const Text('再試行'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isComposing || _composedImage == null) {
      return Container(
        color: AppColors.surfaceVariant,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: AppSpacing.md),
              Text('ただいま窓口で発行手続き中...',
                  style: TextStyle(
                      color: AppColors.textMedium, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Image.memory(_composedImage!, fit: BoxFit.contain);
  }

  Widget _buildCongratulationMessage() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified,
                color: AppColors.accent, size: AppSpacing.iconLg),
            SizedBox(width: AppSpacing.sm),
            Text(
              '免許証を交付しました！',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          '保存やシェアして自慢しよう',
          style: TextStyle(fontSize: 14, color: AppColors.textMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '※ この免許証は公的な証明書ではありません',
          style: TextStyle(fontSize: 11, color: AppColors.textLight),
        ),
      ],
    );
  }

  /// 下部アクションボタン群（動的優先順位）
  ///
  /// 初回: シェアが大ボタン → 保存+もう1枚が小
  /// 2回目以降: もう1枚が大ボタン → 保存+シェアが小
  Widget _buildBottomBar() {
    final bool isReady = _autoSaved && _error == null;
    final countAsync = ref.watch(licenseCountProvider);
    final isFirstLicense =
        countAsync.whenOrNull(data: (c) => c <= 1) ?? true;

    // 大ボタン（ElevatedButton, フル幅）
    final Widget primaryButton;
    // 小ボタン2つ（OutlinedButton, 横並び）
    final Widget secondaryRow;

    if (isFirstLicense) {
      // 初回: シェア大 → 保存+もう1枚
      primaryButton = _buildPrimaryButton(
        onPressed: isReady && !_isSharing ? _shareImage : null,
        icon: _isSharing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.share),
        label: _isSharing ? 'シェア中...' : 'シェアする',
      );
      secondaryRow = Row(
        children: [
          Expanded(child: _buildSaveButton(isReady)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _buildCreateAnotherButton(isReady)),
        ],
      );
    } else {
      // 2回目以降: もう1枚大 → 保存+シェア
      primaryButton = _buildPrimaryButton(
        onPressed: isReady ? _createAnother : null,
        icon: const Icon(Icons.add_a_photo),
        label: 'もう1枚つくる',
      );
      secondaryRow = Row(
        children: [
          Expanded(child: _buildSaveButton(isReady)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _buildShareButton(isReady)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: double.infinity, child: primaryButton),
          const SizedBox(height: AppSpacing.sm),
          secondaryRow,
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home, size: 18),
            label: const Text('ホームに戻る'),
          ),
        ],
      ),
    );
  }

  /// 大ボタン（ElevatedButton）
  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
    );
  }

  /// カメラロールに保存ボタン（小）
  Widget _buildSaveButton(bool isReady) {
    return OutlinedButton.icon(
      onPressed: isReady && !_isSavingToGallery && !_savedToGallery
          ? _saveToGallery
          : null,
      icon: _isSavingToGallery
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          : Icon(
              _savedToGallery ? Icons.check : Icons.photo_library_outlined,
              size: 20),
      label: Text(_isSavingToGallery
          ? '保存中'
          : _savedToGallery
              ? '保存済み'
              : '保存'),
    );
  }

  /// シェアボタン（小）
  Widget _buildShareButton(bool isReady) {
    return OutlinedButton.icon(
      onPressed: isReady && !_isSharing ? _shareImage : null,
      icon: _isSharing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          : const Icon(Icons.share, size: 20),
      label: Text(_isSharing ? 'シェア中' : 'シェア'),
    );
  }

  /// もう1枚ボタン（小）
  Widget _buildCreateAnotherButton(bool isReady) {
    return OutlinedButton.icon(
      onPressed: isReady ? _createAnother : null,
      icon: const Icon(Icons.add_a_photo, size: 20),
      label: const Text('もう1枚'),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  /// GalException のエラーメッセージを日本語に変換
  String _galErrorMessage(GalException e) {
    switch (e.type) {
      case GalExceptionType.accessDenied:
        return '写真へのアクセスが許可されていません';
      case GalExceptionType.notSupportedFormat:
        return 'この画像形式には対応していません';
      case GalExceptionType.notEnoughSpace:
        return 'ストレージの空き容量が不足しています';
      default:
        return '予期しないエラーが発生しました';
    }
  }
}

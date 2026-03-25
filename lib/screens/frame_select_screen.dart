import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/costume.dart';
import '../models/costume_overlay.dart';
import '../models/license_template.dart';
import '../config/dev_config.dart';
import '../services/license_painter.dart';
import '../services/purchase_manager.dart';
import '../theme/colors.dart';

/// 画面4: フレーム&デコ選択
///
/// 前画面(InfoInputScreen)から受け取ったデータを使い、
/// フレーム色・コスチューム・テンプレートタイプを選択する。
/// 上半分にリアルタイムプレビュー（コスチュームドラッグ対応）、
/// 下半分に選択UIを配置。
class FrameSelectScreen extends StatefulWidget {
  const FrameSelectScreen({super.key});

  @override
  State<FrameSelectScreen> createState() => _FrameSelectScreenState();
}

class _FrameSelectScreenState extends State<FrameSelectScreen>
    with SingleTickerProviderStateMixin {
  // === 前画面から受け取るデータ ===
  Map<String, dynamic>? _extraData;
  int? _editId;
  DateTime? _editCreatedAt;
  String? _photoPath;
  String _petName = '';
  String _species = '';
  String _breed = '';
  String? _birthDateStr;
  bool _birthDateUnknown = false;
  String? _gender;
  String _specialty = '';
  String? _specialtyId;
  String _customCondition = '';
  String _customAddress = '';
  String _licenseType = '';

  // === 選択状態 ===
  String _selectedFrameColorId = 'black';
  TemplateType _selectedTemplateType = TemplateType.japan;
  String _selectedValidityId = 'nap';

  // === コスチュームオーバーレイ ===
  final List<CostumeOverlay> _costumeOverlays = [];
  final Map<String, ui.Image> _costumeImages = {};
  String? _selectedOverlayUid;

  // === 顔ハメ ===
  String? _selectedOutfitId;

  // === 証明写真の背景色 ===
  Color _photoBgColor = const Color(0xFF6A9FCC);

  // === 写真調整パラメータ ===
  double _photoScale = 1.0;
  double _photoOffsetX = 0.0;
  double _photoOffsetY = 0.0;
  double _photoRotation = 0.0;

  // === 写真色調整（明るさ/コントラスト/彩度） ===
  double _photoBrightness = 0.0;
  double _photoContrast = 0.0;
  double _photoSaturation = 0.0;

  // === 背景削除の元画像パス（エディタ間で受け渡し） ===
  String? _originalPhotoPath;

  // === ドラッグ操作用 ===
  double _dragStartScale = 1.0;

  // === 写真画像（非同期ロード） ===
  ui.Image? _photoImage;
  bool _isLoadingPhoto = false;

  // === 顔ハメ画像 ===
  ui.Image? _outfitImage;

  // === カードフリップアニメーション ===
  late final AnimationController _flipController;
  late final Animation<double> _flipAngle;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _flipAngle = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 3.14159), weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 3.14159, end: 6.28318), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _flipController.dispose();
    _outfitImage?.dispose();
    super.dispose();
  }

  void _showPremiumDialog() {
    final pm = PurchaseManager.instance;
    final package = pm.currentOffering?.availablePackages.firstOrNull;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('プレミアムコスチューム'),
        content: const Text(
          '全47種類のコスチューム・フレーム色が使い放題！\n枚数制限も解除されます。\n\n¥300（買い切り）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('あとで'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: pm.isPurchasing,
            builder: (_, purchasing, __) => ElevatedButton(
              onPressed: purchasing || package == null
                  ? null
                  : () async {
                      final success = await pm.purchasePackage(package);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (success && mounted) setState(() {});
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: purchasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('購入する', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  /// フレーム/テンプレート変更時にフリップ演出
  void _animateFlip() {
    _flipController.forward(from: 0.0);
  }

  /// 写真・デコ統合エディタを開く
  Future<void> _openEditor() async {
    final template = LicenseTemplate.fromId(_selectedTemplateType.id);
    final licenseType = LicenseType.findById(_licenseType);
    final validityOption = ValidityOption.findById(_selectedValidityId);
    final validityText = validityOption.textForTemplate(_selectedTemplateType);

    final result = await context.push<Map<String, dynamic>>(
      '/create/editor',
      extra: {
        'photoPath': _photoPath,
        'petName': _petName,
        'species': _species,
        'breed': _breed,
        'birthDate': _birthDateStr,
        'birthDateUnknown': _birthDateUnknown,
        'gender': _gender,
        'specialty': _specialty,
        'specialtyId': _specialtyId,
        'customCondition': _customCondition,
        'customAddress': _customAddress,
        'licenseTypeLabel': licenseType.label,
        'validityText': validityText,
        'frameColorId': _selectedFrameColorId,
        'templateType': _selectedTemplateType.id,
        'costumeOverlays':
            _costumeOverlays.map((o) => o.toMap()).toList(),
        'photoScale': _photoScale,
        'photoOffsetX': _photoOffsetX,
        'photoOffsetY': _photoOffsetY,
        'photoRotation': _photoRotation,
        'photoBrightness': _photoBrightness,
        'photoContrast': _photoContrast,
        'photoSaturation': _photoSaturation,
        'outfitId': _selectedOutfitId,
        'originalPhotoPath': _originalPhotoPath,
      },
    );

    // エディタからの戻りデータを反映
    if (result != null) {
      final newPath = result['photoPath'] as String?;
      final newOutfitId = result['outfitId'] as String?;

      // 同期的にステートを更新（写真パス・パラメータ・オーバーレイ）
      setState(() {
        _photoScale = (result['photoScale'] as num?)?.toDouble() ?? _photoScale;
        _photoOffsetX =
            (result['photoOffsetX'] as num?)?.toDouble() ?? _photoOffsetX;
        _photoOffsetY =
            (result['photoOffsetY'] as num?)?.toDouble() ?? _photoOffsetY;
        _photoRotation =
            (result['photoRotation'] as num?)?.toDouble() ?? _photoRotation;
        _photoBrightness =
            (result['photoBrightness'] as num?)?.toDouble() ?? _photoBrightness;
        _photoContrast =
            (result['photoContrast'] as num?)?.toDouble() ?? _photoContrast;
        _photoSaturation =
            (result['photoSaturation'] as num?)?.toDouble() ?? _photoSaturation;
        _selectedOutfitId = newOutfitId;
        // コスチュームオーバーレイ
        final overlayMaps = result['costumeOverlays'] as List<dynamic>?;
        if (overlayMaps != null) {
          _costumeOverlays.clear();
          for (final map in overlayMaps) {
            _costumeOverlays
                .add(CostumeOverlay.fromMap(map as Map<String, dynamic>));
          }
        }
      });

      // 背景削除の元画像パスを保持
      _originalPhotoPath = result['originalPhotoPath'] as String?;

      // 非同期の画像ロードは setState の外で実行
      if (newPath != null && newPath != _photoPath) {
        _photoPath = newPath;
        _isLoadingPhoto = false; // ガード解除
        await _loadPhoto(newPath);
      }
      // 顔ハメ画像ロード
      _loadOutfitImage(newOutfitId);
      // コスチュームオーバーレイ画像ロード
      _loadCostumeImages();
    }
  }

  /// コスチュームオーバーレイの画像をアセットからロード
  Future<void> _loadCostumeImages() async {
    final loadedIds = <String>{};
    for (final overlay in _costumeOverlays) {
      if (_costumeImages.containsKey(overlay.costumeId)) continue;
      if (loadedIds.contains(overlay.costumeId)) continue;
      loadedIds.add(overlay.costumeId);

      final costume = Costume.findById(overlay.costumeId);
      try {
        final data = await rootBundle.load(costume.assetPath);
        final bytes = data.buffer.asUint8List();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (!mounted) return;
        setState(() {
          _costumeImages[overlay.costumeId] = frame.image;
        });
      } catch (e) {
        debugPrint('Costume asset not found: ${costume.assetPath}');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra =
        GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    if (extra.isEmpty) return;

    // 既にデータ初期化済みなら再初期化しない
    // （エディタからのpop、←で戻った時に選択状態・編集結果を保持）
    if (_extraData != null) {
      return;
    }
    _initExtraData(extra);
  }

  /// GoRouterState.extra からデータを取り出して各フィールドにセット
  void _initExtraData(Map<String, dynamic> extra) {
    _extraData = extra;
    _editId = extra['editId'] as int?;
    _editCreatedAt = extra['createdAt'] as DateTime?;
    _photoPath = extra['photoPath'] as String?;
    _petName = extra['petName'] as String? ?? '';
    _species = extra['species'] as String? ?? '';
    _breed = extra['breed'] as String? ?? '';
    _birthDateStr = extra['birthDate'] as String?;
    _birthDateUnknown = extra['birthDateUnknown'] as bool? ?? false;
    _gender = extra['gender'] as String?;
    _specialty = extra['specialty'] as String? ?? '';
    _specialtyId = extra['specialtyId'] as String?;
    _customCondition = extra['customCondition'] as String? ?? '';
    _customAddress = extra['customAddress'] as String? ?? '';
    _licenseType = extra['licenseType'] as String? ?? 'mofumofu';

    // 編集時は既存の選択状態を復元、新規はデフォルト
    _selectedFrameColorId = extra['frameColor'] as String? ?? 'black';
    final templateStr = extra['templateType'] as String?;
    _selectedTemplateType = templateStr != null
        ? TemplateType.fromId(templateStr)
        : TemplateType.japan;
    _selectedValidityId = extra['validityId'] as String? ?? 'nap';

    // エディタから引き継いだデータを復元
    _photoScale = (extra['photoScale'] as num?)?.toDouble() ?? 1.0;
    _photoOffsetX = (extra['photoOffsetX'] as num?)?.toDouble() ?? 0.0;
    _photoOffsetY = (extra['photoOffsetY'] as num?)?.toDouble() ?? 0.0;
    _photoRotation = (extra['photoRotation'] as num?)?.toDouble() ?? 0.0;
    _photoBrightness = (extra['photoBrightness'] as num?)?.toDouble() ?? 0.0;
    _photoContrast = (extra['photoContrast'] as num?)?.toDouble() ?? 0.0;
    _photoSaturation = (extra['photoSaturation'] as num?)?.toDouble() ?? 0.0;
    _selectedOutfitId = extra['outfitId'] as String?;
    _originalPhotoPath = extra['originalPhotoPath'] as String?;

    // 証明写真の背景色を復元
    final bgColorValue = extra['photoBgColor'] as int?;
    if (bgColorValue != null) {
      _photoBgColor = Color(bgColorValue);
    }

    // コスチュームオーバーレイ復元
    _costumeOverlays.clear();
    _selectedOverlayUid = null;
    final overlayMaps = extra['costumeOverlays'] as List<dynamic>?;
    if (overlayMaps != null) {
      for (final map in overlayMaps) {
        _costumeOverlays
            .add(CostumeOverlay.fromMap(map as Map<String, dynamic>));
      }
    }

    // 写真を再ロード
    _photoImage = null;
    _isLoadingPhoto = false;
    if (_photoPath != null && _photoPath!.isNotEmpty) {
      _loadPhoto(_photoPath!);
    }

    // 顔ハメ画像をロード
    _loadOutfitImage(_selectedOutfitId);

    // コスチューム画像をロード
    if (_costumeOverlays.isNotEmpty) {
      _loadCostumeImages();
    }
  }

  /// 写真ファイルを ui.Image にデコード
  Future<void> _loadPhoto(String path) async {
    if (_isLoadingPhoto) return;
    _isLoadingPhoto = true;

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _photoImage?.dispose();
          _photoImage = frame.image;
          _isLoadingPhoto = false;
        });
      }
    } catch (e) {
      debugPrint('写真ロードエラー: $e');
      if (mounted) {
        setState(() {
          _isLoadingPhoto = false;
        });
      }
    }
  }

  Future<void> _loadOutfitImage(String? outfitId) async {
    _outfitImage?.dispose();
    _outfitImage = null;

    if (outfitId == null) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final costume = Costume.findById(outfitId);
      final data = await rootBundle.load(costume.assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _outfitImage = frame.image;
        });
      }
    } catch (e) {
      debugPrint('顔ハメ画像ロードエラー: $e');
    }
  }

  DateTime? get _birthDate {
    if (_birthDateStr == null || _birthDateStr!.isEmpty) return null;
    return DateTime.tryParse(_birthDateStr!);
  }

  LicenseTemplate get _currentTemplate {
    return LicenseTemplate.fromType(_selectedTemplateType);
  }

  String get _licenseTypeLabel {
    return LicenseType.findById(_licenseType).label;
  }

  // ---------------------------------------------------------------------------
  // コスチューム操作
  // ---------------------------------------------------------------------------

  /// 指定UIDのオーバーレイを削除
  void _removeOverlay(String uid) {
    setState(() {
      _costumeOverlays.removeWhere((o) => o.uid == uid);
      if (_selectedOverlayUid == uid) {
        _selectedOverlayUid = null;
      }
    });
  }

  /// コスチュームタイプ別の色
  Color _costumeTypeColor(CostumeType type) {
    switch (type) {
      case CostumeType.accessory:
        return const Color(0xFF2196F3);
      case CostumeType.stamp:
        return const Color(0xFFE91E63);
      case CostumeType.outfit:
        return const Color(0xFF4CAF50);
    }
  }

  /// コスチューム別のプレースホルダアイコン
  IconData _costumeIcon(String costumeId) {
    switch (costumeId) {
      case 'cap':
        return Icons.sports_baseball;
      case 'sunglasses':
        return Icons.visibility;
      case 'bowtie':
        return Icons.dry_cleaning;
      case 'heart':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'speech':
        return Icons.chat_bubble;
      case 'pawprint':
        return Icons.pets;
      case 'gakuran':
        return Icons.school;
      case 'sailor':
        return Icons.anchor;
      case 'kimono':
        return Icons.checkroom;
      case 'tuxedo':
        return Icons.business_center;
      case 'pirate':
        return Icons.sailing;
      default:
        return Icons.image;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 編集データを持って情報入力画面に返す
        context.pop(<String, dynamic>{
          'photoPath': _photoPath,
          'photoScale': _photoScale,
          'photoOffsetX': _photoOffsetX,
          'photoOffsetY': _photoOffsetY,
          'photoRotation': _photoRotation,
          'costumeOverlays':
              _costumeOverlays.map((o) => o.toMap()).toList(),
          'outfitId': _selectedOutfitId,
          'originalPhotoPath': _originalPhotoPath,
          'templateType': _selectedTemplateType.id,
          'frameColor': _selectedFrameColorId,
          'validityId': _selectedValidityId,
          'photoBgColor': _photoBgColor.value,
          'photoBrightness': _photoBrightness,
          'photoContrast': _photoContrast,
          'photoSaturation': _photoSaturation,
        });
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('フレーム&デコ'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          // === ライブプレビュー（上部40%） ===
          _buildPreviewArea(context),
          // === 選択UI（下部スクロール） ===
          // === 選択UI（下部スクロール・アコーディオン） ===
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
              children: [
                // ── セクション1: コスチューム・写真調整（初期展開） ──
                _buildAccordion(
                  title: 'コスチューム・写真調整',
                  icon: Icons.checkroom,
                  initiallyExpanded: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _buildEditorButton(),
                  ),
                ),

                // ── セクション2: フレーム色 ──
                _buildAccordion(
                  title: 'フレーム色',
                  icon: Icons.palette_outlined,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _buildFrameColorSelector(),
                  ),
                ),

                // ── セクション3: 証明写真の背景色 ──
                _buildAccordion(
                  title: '証明写真の背景色',
                  icon: Icons.photo_outlined,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _buildPhotoBgColorSelector(),
                  ),
                ),

                // ── セクション3.5: 写真の色調整 ──
                _buildAccordion(
                  title: '写真の色調整',
                  icon: Icons.tune,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _buildPhotoColorAdjustment(),
                  ),
                ),

                // ── セクション4: 有効期限テキスト ──
                _buildAccordion(
                  title: '有効期限テキスト',
                  icon: Icons.event_outlined,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _buildValiditySelector(),
                  ),
                ),

                // ── セクション5: テンプレートタイプ ──
                _buildAccordion(
                  title: 'テンプレートタイプ',
                  icon: Icons.style_outlined,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _buildTemplateTypeSelector(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomButton(context),
    ),
    );
  }

  // ---------------------------------------------------------------------------
  // ライブプレビュー（インタラクティブ）
  // ---------------------------------------------------------------------------

  Widget _buildPreviewArea(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final previewHeight = screenHeight * 0.3;

    return Container(
      height: previewHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: _isLoadingPhoto
            ? const CircularProgressIndicator(color: AppColors.primary)
            : AnimatedBuilder(
                animation: _flipAngle,
                builder: (context, child) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_flipAngle.value),
                  child: child,
                ),
                child: _buildInteractivePreview(),
              ),
      ),
    );
  }

  Widget _buildInteractivePreview() {
    final template = _currentTemplate;
    final outputSize = template.outputSize;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: outputSize.width / outputSize.height,
        child: CustomPaint(
          painter: LicensePainter(
            template: template,
            frameColorId: _selectedFrameColorId,
            photoImage: _photoImage,
            costumeOverlays: _costumeOverlays,
            costumeImages: _costumeImages,
            photoScale: _photoScale,
            photoOffsetX: _photoOffsetX,
            photoOffsetY: _photoOffsetY,
            photoRotation: _photoRotation,
            outfitId: _selectedOutfitId,
            outfitImage: _outfitImage,
            photoBgColor: _photoBgColor,
            photoColorFilter: LicensePainter.buildPhotoColorFilter(
              brightness: _photoBrightness,
              contrast: _photoContrast,
              saturation: _photoSaturation,
            ),
            petName: _petName,
            species: _species,
            breed: _breed.isNotEmpty ? _breed : null,
            birthDate: _birthDate,
            birthDateUnknown: _birthDateUnknown,
            gender: _gender,
            specialty:
                _specialty.isNotEmpty ? _specialty : null,
            specialtyId: _specialtyId,
            customCondition: _customCondition.isNotEmpty
                ? _customCondition
                : null,
            customAddress: _customAddress.isNotEmpty
                ? _customAddress
                : null,
            licenseTypeLabel: _licenseTypeLabel,
            validityText:
                ValidityOption.findById(_selectedValidityId)
                    .textForTemplate(_selectedTemplateType),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  /// ドラッグ可能なコスチュームオーバーレイWidget
  Widget _buildDraggableOverlay(CostumeOverlay overlay, Size previewSize) {
    final costume = Costume.findById(overlay.costumeId);
    // 写真エリアの比率を取得（座標変換用）
    final pr = _currentTemplate.photoRectRatio;
    final photoPreviewW = previewSize.width * pr.width;
    // サイズ: 写真エリア基準
    final baseW = photoPreviewW * costume.defaultScale * overlay.scale;
    final baseH = baseW;
    // 位置: 写真ローカル座標(0〜1) → カード座標に変換
    final cardCx = pr.left + overlay.cx * pr.width;
    final cardCy = pr.top + overlay.cy * pr.height;
    final left = cardCx * previewSize.width - baseW / 2;
    final top = cardCy * previewSize.height - baseH / 2;
    final isSelected = _selectedOverlayUid == overlay.uid;
    final typeColor = _costumeTypeColor(costume.type);

    return Positioned(
      left: left,
      top: top,
      width: baseW,
      height: baseH,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedOverlayUid = isSelected ? null : overlay.uid;
          });
        },
        onScaleStart: (details) {
          _selectedOverlayUid = overlay.uid;
          _dragStartScale = overlay.scale;
        },
        onScaleUpdate: (details) {
          setState(() {
            // ドラッグ（位置移動）— 写真エリア基準で delta を計算
            overlay.cx += details.focalPointDelta.dx / (previewSize.width * pr.width);
            overlay.cy += details.focalPointDelta.dy / (previewSize.height * pr.height);
            // ピンチ（スケール変更）
            if (details.scale != 1.0) {
              overlay.scale =
                  (_dragStartScale * details.scale).clamp(0.3, 4.0);
            }
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // コスチューム画像（アセットがあれば表示、なければプレースホルダ）
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                costume.assetPath,
                width: baseW,
                height: baseH,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : typeColor,
                      width: isSelected ? 2.5 : 1.5,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _costumeIcon(overlay.costumeId),
                          size: baseW * 0.35,
                          color: typeColor.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          costume.name,
                          style: TextStyle(
                            fontSize: (baseW * 0.12).clamp(8.0, 14.0),
                            color: typeColor,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 選択時の枠線
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            // リサイズハンドル（選択時のみ、左上）
            if (isSelected)
              Positioned(
                left: -12,
                top: -12,
                child: GestureDetector(
                  onPanStart: (_) {
                    _dragStartScale = overlay.scale;
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      // 右下方向にドラッグ→拡大、左上方向→縮小
                      final delta = (details.delta.dx + details.delta.dy) / 2;
                      final scaleDelta = delta / (previewSize.width * 0.3);
                      overlay.scale =
                          (overlay.scale + scaleDelta).clamp(0.3, 4.0);
                    });
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            // 削除ボタン（選択時のみ、右上）
            if (isSelected)
              Positioned(
                right: -6,
                top: -6,
                child: GestureDetector(
                  onTap: () => _removeOverlay(overlay.uid),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 写真・デコ編集ボタン
  // ---------------------------------------------------------------------------

  Widget _buildEditorButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openEditor,
        icon: const Icon(Icons.edit, size: 18),
        label: const Text('写真・デコを編集する'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // セクション1: フレーム色選択
  // ---------------------------------------------------------------------------

  Widget _buildFrameColorSelector() {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: FrameColor.all.map((fc) {
        final isSelected = _selectedFrameColorId == fc.id;
        final isLocked = fc.isPremium && !PurchaseManager.instance.isPremium;

        return Semantics(
          label: '${fc.label}${isLocked ? "（ロック中）" : ""}',
          selected: isSelected,
          button: true,
          child: GestureDetector(
          onTap: isLocked
              ? () => _showPremiumDialog()
              : () {
                  if (_selectedFrameColorId != fc.id) {
                    setState(() {
                      _selectedFrameColorId = fc.id;
                    });
                    _animateFlip();
                  }
                },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: fc.color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: AppColors.primary, width: 3)
                      : Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: isLocked
                    ? Icon(
                        Icons.lock,
                        size: 20,
                        color: fc.textColor.withValues(alpha: 0.7),
                      )
                    : isSelected
                        ? Icon(
                            Icons.check,
                            size: 20,
                            color: fc.textColor,
                          )
                        : null,
              ),
              const SizedBox(height: 4),
              Text(
                fc.label,
                style: TextStyle(
                  fontSize: 11,
                  color: isLocked
                      ? Colors.grey.shade400
                      : isSelected
                          ? AppColors.primary
                          : AppColors.textDark,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // セクション: 証明写真の背景色
  // ---------------------------------------------------------------------------

  static const _photoBgColors = <(String, Color)>[
    ('白', Color(0xFFFFFFFF)),
    ('水色', Color(0xFF6A9FCC)),
    ('ピンク', Color(0xFFF8BBD0)),
    ('黄', Color(0xFFFFF9C4)),
    ('緑', Color(0xFFC8E6C9)),
    ('グレー', Color(0xFFBDBDBD)),
    ('ラベンダー', Color(0xFFD1C4E9)),
    ('オレンジ', Color(0xFFFFE0B2)),
  ];

  Widget _buildPhotoBgColorSelector() {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: _photoBgColors.map((entry) {
        final (label, color) = entry;
        final isSelected = _photoBgColor.value == color.value;

        return GestureDetector(
          onTap: () {
            if (!isSelected) {
              setState(() => _photoBgColor = color);
              _animateFlip();
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: AppColors.primary, width: 3)
                      : Border.all(color: Colors.grey.shade300, width: 1.5),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 18, color: Colors.black54)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? AppColors.primary : AppColors.textDark,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // セクション3.5: 写真の色調整（明るさ/コントラスト/彩度）
  // ---------------------------------------------------------------------------

  Widget _buildPhotoColorAdjustment() {
    Widget buildSlider({
      required String label,
      required IconData icon,
      required double value,
      required ValueChanged<double> onChanged,
    }) {
      return Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMedium),
          const SizedBox(width: 6),
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textDark),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: -1.0,
              max: 1.0,
              divisions: 40,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.primary.withValues(alpha: 0.15),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                color: value != 0 ? AppColors.primary : AppColors.textLight,
                fontWeight: value != 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      );
    }

    final hasAdjustment =
        _photoBrightness != 0.0 || _photoContrast != 0.0 || _photoSaturation != 0.0;

    return Column(
      children: [
        buildSlider(
          label: '明るさ',
          icon: Icons.brightness_6,
          value: _photoBrightness,
          onChanged: (v) {
            setState(() => _photoBrightness = v);
          },
        ),
        buildSlider(
          label: 'コントラスト',
          icon: Icons.contrast,
          value: _photoContrast,
          onChanged: (v) {
            setState(() => _photoContrast = v);
          },
        ),
        buildSlider(
          label: '彩度',
          icon: Icons.palette_outlined,
          value: _photoSaturation,
          onChanged: (v) {
            setState(() => _photoSaturation = v);
          },
        ),
        if (hasAdjustment)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _photoBrightness = 0.0;
                  _photoContrast = 0.0;
                  _photoSaturation = 0.0;
                });
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('リセット', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMedium,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // セクション3: 有効期限テキスト選択
  // ---------------------------------------------------------------------------

  Widget _buildValiditySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ValidityOption.all.map((option) {
          final isSelected = _selectedValidityId == option.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(option.text),
              selected: isSelected,
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: isSelected ? AppColors.primary : Colors.grey.shade400,
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primary : AppColors.textDark,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedValidityId = option.id;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // セクション4: テンプレートタイプ選択
  // ---------------------------------------------------------------------------

  Widget _buildTemplateTypeSelector() {
    return Row(
      children: TemplateType.values.map((type) {
        final isSelected = _selectedTemplateType == type;
        final icon =
            type == TemplateType.japan ? Icons.temple_buddhist : Icons.flag;
        final description =
            type == TemplateType.japan ? '日本の運転免許証風' : 'アメリカのID風';

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: type == TemplateType.japan ? 6 : 0,
              left: type == TemplateType.usa ? 6 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                if (_selectedTemplateType != type) {
                  setState(() {
                    _selectedTemplateType = type;
                  });
                  _animateFlip();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 32,
                      color:
                          isSelected ? AppColors.primary : Colors.grey.shade500,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.primary : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // 下部ボタン
  // ---------------------------------------------------------------------------

  Widget _buildBottomButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _navigateToPreview,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: const Text('次へ'),
        ),
      ),
    );
  }

  /// 次の画面（プレビュー）へ遷移
  Future<void> _navigateToPreview() async {
    final resultEditId = await context.push<int?>('/create/preview', extra: {
      if (_editId != null) 'editId': _editId,
      if (_editCreatedAt != null) 'createdAt': _editCreatedAt,
      'photoPath': _photoPath,
      'petName': _petName,
      'species': _species,
      'breed': _breed,
      'birthDate': _birthDateStr,
      'birthDateUnknown': _birthDateUnknown,
      'gender': _gender,
      'specialty': _specialty,
      'specialtyId': _specialtyId,
      'customCondition': _customCondition,
      'customAddress': _customAddress,
      'licenseType': _licenseType,
      'frameColor': _selectedFrameColorId,
      'costumeId': _costumeOverlays.isNotEmpty
          ? _costumeOverlays.first.costumeId
          : 'none',
      'templateType': _selectedTemplateType.id,
      'validityId': _selectedValidityId,
      'costumeOverlays':
          _costumeOverlays.map((o) => o.toMap()).toList(),
      'photoScale': _photoScale,
      'photoOffsetX': _photoOffsetX,
      'photoOffsetY': _photoOffsetY,
      'photoRotation': _photoRotation,
      'photoBrightness': _photoBrightness,
      'photoContrast': _photoContrast,
      'photoSaturation': _photoSaturation,
      'outfitId': _selectedOutfitId,
      'photoBgColor': _photoBgColor.value,
    });
    // プレビューから戻ったとき、保存済みのeditIdを反映（重複insert防止）
    if (resultEditId != null) {
      _editId = resultEditId;
    }
  }

  // ---------------------------------------------------------------------------
  // 共通UI部品
  // ---------------------------------------------------------------------------

  Widget _buildAccordion({
    required String title,
    required IconData icon,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, size: 20, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20),
        childrenPadding: EdgeInsets.zero,
        children: [child],
      ),
    );
  }
}

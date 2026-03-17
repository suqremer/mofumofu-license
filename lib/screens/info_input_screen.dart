import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/breed_data.dart';
import '../models/license_template.dart';
import '../services/app_preferences.dart';
import '../theme/colors.dart';

/// 種別リスト
const speciesList = ['猫', '犬', 'うさぎ', 'ハムスター', '鳥', 'その他'];

/// 性別リスト
const genderList = ['♂', '♀', '不明'];

/// 画面3: 免許証情報入力
class InfoInputScreen extends StatefulWidget {
  const InfoInputScreen({super.key});

  @override
  State<InfoInputScreen> createState() => _InfoInputScreenState();
}

class _InfoInputScreenState extends State<InfoInputScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  // テキスト入力コントローラ
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _addressController = TextEditingController();

  // 特技自由記述用
  final _customSpecialtyController = TextEditingController();
  final _customConditionController = TextEditingController();

  // 選択状態
  String? _selectedSpecies;
  String? _selectedGender;
  DateTime? _selectedBirthDate;
  bool _birthDateUnknown = false;
  bool _breedUnknown = false;
  String? _selectedSpecialtyId;
  bool _showBreedOnLicense = true;
  bool _useCustomAddress = false;

  // 前画面から受け取った写真パス
  String? _photoPath;

  /// 編集モード: 既存免許証のID（null なら新規作成）
  int? _editId;
  DateTime? _editCreatedAt;
  bool _editLoaded = false;

  /// 編集時のテンプレート情報（中継用）
  String? _templateType;
  String? _frameColor;
  String? _costumeId;

  /// フレーム&デコ/エディタから引き継ぐデータ（中継用）
  double _photoScale = 1.0;
  double _photoOffsetX = 0.0;
  double _photoOffsetY = 0.0;
  List<Map<String, dynamic>>? _costumeOverlays;
  String? _outfitId;
  String? _originalPhotoPath;
  String? _validityId;
  int? _photoBgColor;

  /// ドラフト復元済みフラグ
  bool _draftRestored = false;

  /// 初期化済みフラグ（didChangeDependenciesの再発火防止）
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final extra = GoRouterState.of(context).extra;

    // 編集モード: extraがMapで editId を含む
    if (extra is Map<String, dynamic> && extra.containsKey('editId')) {
      _editLoaded = true;
      _editId = extra['editId'] as int;
      _editCreatedAt = extra['createdAt'] as DateTime?;
      _photoPath = extra['photoPath'] as String?;
      _loadEditData(extra);
      return;
    }

    // 新規作成モード: extraは写真パス（String）
    final extraPath = extra as String?;
    if (extraPath != null && extraPath != _photoPath) {
      _photoPath = extraPath;
      _resetForm();
      _draftRestored = false;
      _restoreDraftIfSamePhoto(extraPath);
    } else if (extraPath != null) {
      _photoPath = extraPath;
    } else if (!_draftRestored) {
      _restoreDraft();
    }
  }

  /// 編集データをフォームに反映
  void _loadEditData(Map<String, dynamic> data) {
    _nameController.text = data['petName'] as String? ?? '';
    _selectedSpecies = data['species'] as String?;
    _breedController.text = data['breed'] as String? ?? '';
    _selectedGender = data['gender'] as String?;

    final birthStr = data['birthDate'] as String?;
    if (birthStr != null && birthStr.isNotEmpty) {
      try {
        _selectedBirthDate = DateTime.parse(birthStr);
      } catch (e) {
        debugPrint('日付パース失敗: $birthStr ($e)');
      }
    } else {
      _selectedBirthDate = null;
    }

    final specialty = data['specialty'] as String?;
    if (specialty != null && specialty.isNotEmpty && _selectedSpecies != null) {
      // 特技をIDに逆引き
      final options = SpecialtyOption.forSpecies(_selectedSpecies!);
      final match = options.where((o) => o.label == specialty).firstOrNull;
      _selectedSpecialtyId = match?.id ?? 'custom';
      if (_selectedSpecialtyId == 'custom') {
        _customSpecialtyController.text = specialty;
      }
    }

    // テンプレート情報を保持（中継用）
    _templateType = data['templateType'] as String?;
    _frameColor = data['frameColor'] as String?;
    _costumeId = data['costumeId'] as String?;

    // extra_data から復元（コスチューム配置・写真調整等）
    _photoScale = (data['photoScale'] as num?)?.toDouble() ?? 1.0;
    _photoOffsetX = (data['photoOffsetX'] as num?)?.toDouble() ?? 0.0;
    _photoOffsetY = (data['photoOffsetY'] as num?)?.toDouble() ?? 0.0;
    _costumeOverlays = (data['costumeOverlays'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _outfitId = data['outfitId'] as String?;
    _validityId = data['validityId'] as String?;
    final bgColor = data['photoBgColor'];
    if (bgColor is int) _photoBgColor = bgColor;

    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // バックグラウンドに入る時にドラフトを保存
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveDraft();
    }
  }

  /// フォーム全体をリセット（新規作成時）
  void _resetForm() {
    _nameController.clear();
    _breedController.clear();
    _specialtyController.clear();
    _addressController.clear();
    _useCustomAddress = false;
    _customSpecialtyController.clear();
    _customConditionController.clear();
    _selectedSpecies = null;
    _selectedGender = null;
    _selectedBirthDate = null;
    _birthDateUnknown = false;
    _breedUnknown = false;
    _selectedSpecialtyId = null;
    _showBreedOnLicense = true;
  }

  /// ドラフトの写真パスが今の写真パスと一致する場合のみ復元
  /// （同じ写真の作成途中 = 前回の続き。違う写真 = 新規作成）
  void _restoreDraftIfSamePhoto(String currentPhotoPath) {
    final draft = AppPreferences.getDraft();
    if (draft == null) return;

    final draftPhoto = draft['photoPath'] as String?;
    if (draftPhoto != currentPhotoPath) return; // 違う写真 → 新規作成なので復元しない

    _draftRestored = true;
    _applyDraft(draft);
  }

  /// ドラフトを保存
  void _saveDraft() {
    if (_photoPath == null) return;
    AppPreferences.saveDraft({
      'photoPath': _photoPath,
      'petName': _nameController.text,
      'species': _selectedSpecies,
      'breed': _breedController.text,
      'birthDate': _selectedBirthDate?.toIso8601String(),
      'birthDateUnknown': _birthDateUnknown.toString(),
      'gender': _selectedGender,
      'specialtyId': _selectedSpecialtyId,
      'customSpecialty': _customSpecialtyController.text,
      'customCondition': _customConditionController.text,
      'customAddress': _addressController.text,
      'useCustomAddress': _useCustomAddress.toString(),
      'showBreedOnLicense': _showBreedOnLicense.toString(),
      'breedUnknown': _breedUnknown.toString(),
    });
  }

  /// ドラフトを復元（extraなしの場合 = アプリ復帰時）
  void _restoreDraft() {
    if (_draftRestored) return;
    _draftRestored = true;

    final draft = AppPreferences.getDraft();
    if (draft == null) return;

    _photoPath ??= draft['photoPath'] as String?;
    _applyDraft(draft);
  }

  /// ドラフトデータをフォームに適用
  void _applyDraft(Map<String, dynamic> draft) {
    final name = draft['petName'] as String?;
    if (name != null && name.isNotEmpty) {
      _nameController.text = name;
    }
    _selectedSpecies = draft['species'] as String?;
    _selectedGender = draft['gender'] as String?;
    _selectedSpecialtyId = draft['specialtyId'] as String?;

    final birthStr = draft['birthDate'] as String?;
    if (birthStr != null && birthStr.isNotEmpty) {
      try {
        _selectedBirthDate = DateTime.parse(birthStr);
      } catch (e) {
        debugPrint('ドラフト日付パース失敗: $birthStr ($e)');
      }
    }

    final breed = draft['breed'] as String?;
    if (breed != null) _breedController.text = breed;

    final customSpecialty = draft['customSpecialty'] as String?;
    if (customSpecialty != null) {
      _customSpecialtyController.text = customSpecialty;
    }
    final customCondition = draft['customCondition'] as String?;
    if (customCondition != null) {
      _customConditionController.text = customCondition;
    }
    final customAddress = draft['customAddress'] as String?;
    if (customAddress != null) _addressController.text = customAddress;

    final useCustomAddr = draft['useCustomAddress'] as String?;
    if (useCustomAddr == 'true') _useCustomAddress = true;

    final showBreed = draft['showBreedOnLicense'] as String?;
    if (showBreed == 'false') _showBreedOnLicense = false;

    final birthUnknown = draft['birthDateUnknown'] as String?;
    if (birthUnknown == 'true') _birthDateUnknown = true;

    final breedUnk = draft['breedUnknown'] as String?;
    if (breedUnk == 'true') _breedUnknown = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _breedController.dispose();
    _specialtyController.dispose();
    _addressController.dispose();
    _customSpecialtyController.dispose();
    _customConditionController.dispose();
    super.dispose();
  }

  /// 任意項目にデータが入力済みか（編集モード・ドラフト復元時にアコーディオンを開く）
  bool _hasOptionalData() {
    return _breedController.text.isNotEmpty ||
        _breedUnknown ||
        _selectedBirthDate != null ||
        _birthDateUnknown ||
        _selectedGender != null ||
        _useCustomAddress ||
        _selectedSpecialtyId != null;
  }

  /// 必須項目が入力済みか
  bool get _isFormValid =>
      _nameController.text.trim().isNotEmpty &&
      _selectedSpecies != null;

  // _availableLicenseTypes は将来の課金機能で使うためコード保持

  /// 生年月日ピッカーを表示（スクロール式）
  Future<void> _pickBirthDate() async {
    DateTime tempDate = _selectedBirthDate ?? DateTime.now();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('キャンセル',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                    const Text('生年月日', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedBirthDate = tempDate);
                        Navigator.pop(context);
                      },
                      child: const Text('決定',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: tempDate,
                  minimumDate: DateTime(2000),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (date) => tempDate = date,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 次へ遷移
  Future<void> _goNext() async {
    if (!_isFormValid) return;

    final result = await context.push<Map<String, dynamic>>('/create/frame', extra: {
      if (_editId != null) 'editId': _editId,
      if (_editCreatedAt != null) 'createdAt': _editCreatedAt,
      'photoPath': _photoPath,
      'petName': _nameController.text.trim(),
      'species': _selectedSpecies,
      'breed': _breedUnknown ? '不明' : (_showBreedOnLicense ? _breedController.text.trim() : ''),
      'birthDate': _selectedBirthDate?.toIso8601String(),
      'birthDateUnknown': _birthDateUnknown,
      'gender': _selectedGender,
      'specialtyId': _selectedSpecialtyId,
      'specialty': _selectedSpecialtyId == 'custom'
          ? _customSpecialtyController.text.trim()
          : _selectedSpecialtyId != null
              ? SpecialtyOption.forSpecies(_selectedSpecies!)
                  .firstWhere((o) => o.id == _selectedSpecialtyId,
                      orElse: () => SpecialtyOption.forSpecies(_selectedSpecies!).first)
                  .label
              : '',
      'customCondition': _selectedSpecialtyId == 'custom'
          ? _customConditionController.text.trim()
          : '',
      'customAddress': _useCustomAddress ? _addressController.text.trim() : '',
      'licenseType': 'mofumofu',
      if (_templateType != null) 'templateType': _templateType,
      if (_frameColor != null) 'frameColor': _frameColor,
      if (_costumeId != null) 'costumeId': _costumeId,
      'photoScale': _photoScale,
      'photoOffsetX': _photoOffsetX,
      'photoOffsetY': _photoOffsetY,
      if (_costumeOverlays != null) 'costumeOverlays': _costumeOverlays,
      if (_outfitId != null) 'outfitId': _outfitId,
      if (_originalPhotoPath != null) 'originalPhotoPath': _originalPhotoPath,
      if (_validityId != null) 'validityId': _validityId,
      if (_photoBgColor != null) 'photoBgColor': _photoBgColor,
    });

    // フレーム&デコ画面から戻ってきたデータを保持
    if (result != null && mounted) {
      setState(() {
        _photoPath = result['photoPath'] as String? ?? _photoPath;
        _photoScale = (result['photoScale'] as num?)?.toDouble() ?? _photoScale;
        _photoOffsetX = (result['photoOffsetX'] as num?)?.toDouble() ?? _photoOffsetX;
        _photoOffsetY = (result['photoOffsetY'] as num?)?.toDouble() ?? _photoOffsetY;
        _costumeOverlays = (result['costumeOverlays'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _outfitId = result['outfitId'] as String?;
        _originalPhotoPath = result['originalPhotoPath'] as String?;
        _templateType = result['templateType'] as String? ?? _templateType;
        _frameColor = result['frameColor'] as String? ?? _frameColor;
        _validityId = result['validityId'] as String?;
        _photoBgColor = result['photoBgColor'] as int?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveDraft();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('情報を入力'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // スクロール可能なフォーム本体
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 氏名（ペットの名前）★必須 ──
                    _buildSectionLabel('氏名（ペットの名前）', required: true),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      maxLength: 13,
                      decoration: _inputDecoration(
                        hintText: 'もふたろう',
                        prefixIcon: Icons.pets,
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '名前を入力してください';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // ── 種別 ★必須 ──
                    _buildSectionLabel('種別', required: true),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: speciesList.map((species) {
                          final isSelected = _selectedSpecies == species;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(species),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textDark,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                ),
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedSpecies = selected ? species : null;
                                  // 種別変更で特技をリセット（動物ごとに選択肢が異なるため）
                                  _selectedSpecialtyId = null;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 任意項目（アコーディオン）──
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: _hasOptionalData(),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(
                          'もっとこだわる（任意）',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        subtitle: Text(
                          '入力しなくてもおまかせで自動入力されます',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        children: [
                          const SizedBox(height: 8),

                    // ── 品種（任意・オートコンプリート）──
                    _buildSectionLabel('品種'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _breedUnknown
                              ? TextFormField(
                                  decoration: _inputDecoration(
                                    hintText: '不明',
                                    prefixIcon: Icons.category,
                                  ),
                                  enabled: false,
                                  controller: TextEditingController(text: '不明'),
                                )
                              : _buildBreedAutocomplete(),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('不明'),
                          selected: _breedUnknown,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _breedUnknown ? Colors.white : AppColors.textDark,
                            fontWeight: _breedUnknown ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: _breedUnknown
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                            ),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _breedUnknown = selected;
                              if (selected) {
                                _breedController.clear();
                                _showBreedOnLicense = false;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        SizedBox(
                          height: 32,
                          width: 32,
                          child: Checkbox(
                            value: _showBreedOnLicense,
                            activeColor: AppColors.primary,
                            onChanged: _breedUnknown
                                ? null
                                : (v) => setState(() => _showBreedOnLicense = v ?? true),
                          ),
                        ),
                        GestureDetector(
                          onTap: _breedUnknown
                              ? null
                              : () => setState(() => _showBreedOnLicense = !_showBreedOnLicense),
                          child: Text('免許証に表示する',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _breedUnknown ? Colors.grey.shade400 : Colors.grey.shade600)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── 生年月日（任意）──
                    _buildSectionLabel('生年月日'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _birthDateUnknown ? null : _pickBirthDate,
                            child: AbsorbPointer(
                              child: TextFormField(
                                decoration: _inputDecoration(
                                  hintText: _birthDateUnknown ? '不明' : 'タップして選択',
                                  prefixIcon: Icons.cake,
                                  suffixIcon: _selectedBirthDate != null && !_birthDateUnknown
                                      ? IconButton(
                                          icon: Icon(Icons.clear,
                                              color: Colors.grey.shade400, size: 20),
                                          onPressed: () {
                                            setState(
                                                () => _selectedBirthDate = null);
                                          },
                                        )
                                      : null,
                                ),
                                enabled: !_birthDateUnknown,
                                controller: TextEditingController(
                                  text: _birthDateUnknown
                                      ? '不明'
                                      : _selectedBirthDate != null
                                          ? '${_selectedBirthDate!.year}年'
                                              '${_selectedBirthDate!.month}月'
                                              '${_selectedBirthDate!.day}日'
                                          : '',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('不明'),
                          selected: _birthDateUnknown,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _birthDateUnknown ? Colors.white : AppColors.textDark,
                            fontWeight: _birthDateUnknown ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: _birthDateUnknown
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                            ),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _birthDateUnknown = selected;
                              if (selected) _selectedBirthDate = null;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── 性別（任意）──
                    _buildSectionLabel('性別'),
                    const SizedBox(height: 8),
                    Row(
                      children: genderList.map((gender) {
                        final isSelected = _selectedGender == gender;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(gender),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textDark,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade300,
                              ),
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedGender = selected ? gender : null;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ── 住所 ──
                    _buildSectionLabel('住所'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildAddressChip('おまかせ', selected: !_useCustomAddress,
                          onSelected: (_) => setState(() {
                            _useCustomAddress = false;
                          }),
                        ),
                        const SizedBox(width: 8),
                        _buildAddressChip('自分で書く', selected: _useCustomAddress,
                          onSelected: (_) => setState(() {
                            _useCustomAddress = true;
                          }),
                        ),
                      ],
                    ),
                    if (_useCustomAddress) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        maxLength: 25,
                        decoration: _inputDecoration(
                          hintText: '例: 東京都もふもふ市ふわふわ町1-1',
                          prefixIcon: Icons.home,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📝 参考',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700)),
                            const SizedBox(height: 4),
                            Text('・京都府まぐろ市おさしみ町6-1\n'
                                 '・沖縄県みずあそび市どろんこ町9-4\n'
                                 '・秋田県しろみみ市月見町1-6',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600,
                                height: 1.5)),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text('ペットの名前に合わせて自動で決まるよ',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                    const SizedBox(height: 24),

                    // ── 特技（任意）──
                    _buildSectionLabel('特技'),
                    const SizedBox(height: 8),
                    if (_selectedSpecies != null) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...SpecialtyOption.forSpecies(_selectedSpecies!).map((opt) {
                              final isSelected = _selectedSpecialtyId == opt.id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(opt.label),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textDark,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                    ),
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedSpecialtyId = selected ? opt.id : null;
                                    });
                                  },
                                ),
                              );
                            }),
                            // 「自分で書く」オプション
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: const Text('自分で書く'),
                                selected: _selectedSpecialtyId == 'custom',
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: _selectedSpecialtyId == 'custom' ? Colors.white : AppColors.textDark,
                                  fontWeight: _selectedSpecialtyId == 'custom' ? FontWeight.bold : FontWeight.normal,
                                ),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: _selectedSpecialtyId == 'custom' ? AppColors.primary : Colors.grey.shade300,
                                  ),
                                ),
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedSpecialtyId = selected ? 'custom' : null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 自由記述モードの入力欄
                      if (_selectedSpecialtyId == 'custom') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customSpecialtyController,
                          maxLength: 10,
                          decoration: _inputDecoration(
                            hintText: '特技を入力',
                            prefixIcon: Icons.star,
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '「○○運転しないこと」の○○部分を入力',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _customConditionController,
                                maxLength: 12,
                                decoration: _inputDecoration(
                                  hintText: '例: おやつを食べながら',
                                  prefixIcon: Icons.gavel,
                                ),
                                textInputAction: TextInputAction.done,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 22),
                              child: Text('運転しないこと',
                                style: TextStyle(fontSize: 13, color: AppColors.textDark)),
                            ),
                          ],
                        ),
                      ],
                    ] else ...[
                      Text('種別を先に選択してください',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    ],

                        ], // ExpansionTile children end
                      ),
                    ),

                    // 下部ボタン分のスペース確保
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // 下部固定ボタン
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isFormValid ? _goNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade500,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: _isFormValid ? 2 : 0,
              ),
              child: const Text(
                '次へ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  // _buildLicenseTypeChips は将来の課金機能で使うためコード保持
  // 現在はUIから非表示（デフォルト 'mofumofu' を使用）

  /// ひらがな→カタカナ変換（品種検索用）
  String _hiraganaToKatakana(String input) {
    return input.runes.map((r) {
      // ひらがな(U+3041〜U+3096) → カタカナ(U+30A1〜U+30F6)
      if (r >= 0x3041 && r <= 0x3096) return String.fromCharCode(r + 0x60);
      return String.fromCharCode(r);
    }).join();
  }

  /// 品種オートコンプリート
  Widget _buildBreedAutocomplete() {
    // 選択中の種別に応じた品種リストを取得
    final breeds = _selectedSpecies != null
        ? (breedsBySpecies[_selectedSpecies] ?? <String>[])
        : <String>[];

    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (breeds.isEmpty) return const Iterable<String>.empty();
        if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
        final query = textEditingValue.text.toLowerCase();
        final queryKata = _hiraganaToKatakana(query);
        return breeds.where((b) {
          final lower = b.toLowerCase();
          if (lower.contains(query) || lower.contains(queryKata)) return true;
          // 漢字品種の読みがなでもマッチ
          final reading = breedReadings[b];
          if (reading != null && reading.contains(query)) return true;
          return false;
        });
      },
      onSelected: (selection) {
        _breedController.text = selection;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Autocomplete が独自のコントローラを渡してくるので、
        // 初期値を同期させつつ _breedController にも反映する
        if (controller.text.isEmpty && _breedController.text.isNotEmpty) {
          controller.text = _breedController.text;
        }
        controller.addListener(() {
          _breedController.text = controller.text;
        });
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: _inputDecoration(
            hintText: breeds.isEmpty ? '種別を先に選んでね' : '入力で候補が出るよ',
            prefixIcon: Icons.category,
          ),
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 住所切り替えチップ
  Widget _buildAddressChip(String label, {
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textDark,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.grey.shade300,
        ),
      ),
      onSelected: onSelected,
    );
  }

  /// セクションラベル
  Widget _buildSectionLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text(
            '★必須',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  /// 統一的な InputDecoration
  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

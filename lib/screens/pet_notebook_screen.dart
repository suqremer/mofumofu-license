import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/license_card.dart';
import '../models/pet.dart';
import '../providers/database_provider.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';
import '../widgets/photo_crop_preview.dart';

// === 定数 ===
const _speciesList = ['猫', '犬', 'うさぎ', 'ハムスター', '鳥', 'その他'];
const _genderList = ['♂', '♀', '不明'];
final _dateFormat = DateFormat('yyyy/MM/dd');

/// 種別に対応するアイコンを返す
IconData _speciesIcon(String species) {
  return switch (species) {
    '猫' => Icons.pets,
    '犬' => Icons.pets,
    'うさぎ' => Icons.cruelty_free,
    'ハムスター' => Icons.cruelty_free,
    '鳥' => Icons.flutter_dash,
    _ => Icons.emoji_nature,
  };
}

// =====================================================================
// メイン画面: ペット一覧
// =====================================================================

/// ペット手帳のメイン画面（一覧表示）
class PetNotebookScreen extends ConsumerWidget {
  const PetNotebookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(petsProvider);
    final licensesAsync = ref.watch(licensesProvider);
    final licenses = licensesAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ペット手帳'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: petsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (pets) => pets.isEmpty ? _buildEmptyState(context, ref) : _buildPetList(context, ref, pets, licenses),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPetForm(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('ペットを追加'),
      ),
    );
  }

  /// ペット未登録時の空状態
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 80, color: AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('まだペットが登録されていません', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          Text('右下の＋ボタンから登録できます',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  /// ペット一覧のリスト表示
  Widget _buildPetList(BuildContext context, WidgetRef ref, List<Pet> pets, List<LicenseCard> licenses) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: pets.length,
      itemBuilder: (context, index) {
        final pet = pets[index];
        // ペット名で一致する最新の免許証を検索（licensesは created_at DESC）
        final matchingLicense = licenses
            .where((l) => l.petName == pet.name && l.savedImagePath != null)
            .firstOrNull;
        return _PetCard(
          pet: pet,
          licenseCard: matchingLicense,
          onTap: () => _showPetDetail(context, ref, pet),
        );
      },
    );
  }

  /// ペット追加フォームを表示
  void _showPetForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PetFormSheet(ref: ref),
    );
  }

  /// ペット詳細を表示
  void _showPetDetail(BuildContext context, WidgetRef ref, Pet pet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PetDetailSheet(pet: pet, ref: ref),
    );
  }
}

// =====================================================================
// ペットカード
// =====================================================================

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet, this.licenseCard, required this.onTap});

  final Pet pet;
  final LicenseCard? licenseCard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 年齢を計算
    String? ageText;
    if (pet.birthDate != null) {
      final now = DateTime.now();
      int years = now.year - pet.birthDate!.year;
      if (now.month < pet.birthDate!.month ||
          (now.month == pet.birthDate!.month && now.day < pet.birthDate!.day)) {
        years--;
      }
      ageText = '$years歳';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // アイコン: 免許証があればコスチューム付き証明写真、なければ生写真 or 種別アイコン
              _buildAvatar(),
              const SizedBox(width: 16),
              // 情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        pet.species,
                        if (pet.breed != null && pet.breed!.isNotEmpty) pet.breed!,
                        if (pet.gender != null) pet.gender!,
                        ?ageText,
                      ].join(' / '),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    // 免許証があればコスチューム付き証明写真をクロップ表示
    if (licenseCard != null) {
      return ClipOval(
        child: Container(
          width: 56,
          height: 56,
          color: AppColors.primary.withValues(alpha: 0.15),
          child: PhotoCropPreview(
            card: licenseCard!,
            circular: true,
            size: 56,
          ),
        ),
      );
    }

    // 免許証なし: 生写真 or 種別アイコン
    return CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      backgroundImage: pet.photoPath != null && File(pet.photoPath!).existsSync()
          ? FileImage(File(pet.photoPath!))
          : null,
      child: pet.photoPath != null && File(pet.photoPath!).existsSync()
          ? null
          : Icon(_speciesIcon(pet.species), size: 28, color: AppColors.primary),
    );
  }
}

// =====================================================================
// ペット追加/編集フォーム（BottomSheet）
// =====================================================================

class _PetFormSheet extends StatefulWidget {
  const _PetFormSheet({required this.ref, this.pet});

  final WidgetRef ref;
  final Pet? pet;

  @override
  State<_PetFormSheet> createState() => _PetFormSheetState();
}

class _PetFormSheetState extends State<_PetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _breedCtrl;
  late final TextEditingController _hospitalCtrl;
  late final TextEditingController _microchipCtrl;
  late final TextEditingController _insuranceCtrl;
  late final TextEditingController _memoCtrl;

  String _species = '猫';
  String? _gender;
  DateTime? _birthDate;
  String? _photoPath;

  bool get _isEditing => widget.pet != null;

  @override
  void initState() {
    super.initState();
    final p = widget.pet;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _breedCtrl = TextEditingController(text: p?.breed ?? '');
    _hospitalCtrl = TextEditingController(text: p?.hospitalName ?? '');
    _microchipCtrl = TextEditingController(text: p?.microchipNumber ?? '');
    _insuranceCtrl = TextEditingController(text: p?.insuranceInfo ?? '');
    _memoCtrl = TextEditingController(text: p?.memo ?? '');
    if (p != null) {
      _species = p.species;
      _gender = p.gender;
      _birthDate = p.birthDate;
      _photoPath = p.photoPath;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _hospitalCtrl.dispose();
    _microchipCtrl.dispose();
    _insuranceCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 16),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            // ハンドル
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(_isEditing ? 'ペット情報を編集' : 'ペットを追加', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 写真（任意）
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      backgroundImage: _photoPath != null && File(_photoPath!).existsSync()
                          ? FileImage(File(_photoPath!))
                          : null,
                      child: _photoPath != null && File(_photoPath!).existsSync()
                          ? null
                          : const Icon(Icons.pets, size: 36, color: AppColors.primary),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text('タップして写真を設定', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const SizedBox(height: 16),

            // 名前（必須）
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '名前 *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? '名前を入力してください' : null,
            ),
            const SizedBox(height: 16),

            // 種別（必須）
            const Text('種別 *', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _speciesList.map((s) => ChoiceChip(
                label: Text(s),
                selected: _species == s,
                selectedColor: AppColors.primary.withValues(alpha: 0.3),
                onSelected: (_) => setState(() => _species = s),
              )).toList(),
            ),
            const SizedBox(height: 16),

            // 品種（任意）
            TextFormField(
              controller: _breedCtrl,
              decoration: const InputDecoration(labelText: '品種', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // 生年月日（任意）
            const Text('生年月日', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                DateTime tempDate = _birthDate ?? DateTime.now();
                await showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (ctx) {
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
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text('キャンセル',
                                      style: TextStyle(color: Colors.grey.shade600)),
                                ),
                                const Text('生年月日', style: TextStyle(fontWeight: FontWeight.bold)),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _birthDate = tempDate);
                                    Navigator.pop(ctx);
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
              },
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    hintText: 'タップして選択',
                    prefixIcon: const Icon(Icons.cake, color: AppColors.primary),
                    suffixIcon: _birthDate != null
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 20),
                            onPressed: () => setState(() => _birthDate = null),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  controller: TextEditingController(
                    text: _birthDate != null
                        ? '${_birthDate!.year}年${_birthDate!.month}月${_birthDate!.day}日'
                        : '',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 性別（任意）
            const Text('性別', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _genderList.map((g) => ChoiceChip(
                label: Text(g),
                selected: _gender == g,
                selectedColor: AppColors.primary.withValues(alpha: 0.3),
                onSelected: (selected) => setState(() => _gender = selected ? g : null),
              )).toList(),
            ),
            const SizedBox(height: 16),

            // かかりつけ病院
            TextFormField(
              controller: _hospitalCtrl,
              decoration: const InputDecoration(labelText: 'かかりつけ病院', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // マイクロチップ番号
            TextFormField(
              controller: _microchipCtrl,
              decoration: const InputDecoration(labelText: 'マイクロチップ番号', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // 保険情報
            TextFormField(
              controller: _insuranceCtrl,
              decoration: const InputDecoration(labelText: '保険情報', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // メモ
            TextFormField(
              controller: _memoCtrl,
              decoration: const InputDecoration(labelText: 'メモ', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // 保存ボタン
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: Text(_isEditing ? '更新する' : '登録する', style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 写真を選択
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked == null) return;

    // アプリ内にコピーして保存
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(picked.path);
    final fileName = 'pet_${DateTime.now().millisecondsSinceEpoch}$ext';
    final savedFile = await File(picked.path).copy('${dir.path}/$fileName');

    setState(() => _photoPath = savedFile.path);
  }

  /// ペットを保存
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final pet = Pet(
      id: widget.pet?.id,
      name: _nameCtrl.text.trim(),
      species: _species,
      breed: _breedCtrl.text.trim().isEmpty ? null : _breedCtrl.text.trim(),
      birthDate: _birthDate,
      gender: _gender,
      photoPath: _photoPath,
      hospitalName: _hospitalCtrl.text.trim().isEmpty ? null : _hospitalCtrl.text.trim(),
      microchipNumber: _microchipCtrl.text.trim().isEmpty ? null : _microchipCtrl.text.trim(),
      insuranceInfo: _insuranceCtrl.text.trim().isEmpty ? null : _insuranceCtrl.text.trim(),
      memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
      createdAt: widget.pet?.createdAt ?? now,
      updatedAt: now,
    );

    final db = DatabaseService();
    if (_isEditing) {
      await db.updatePet(pet);
    } else {
      await db.insertPet(pet);
    }
    widget.ref.invalidate(petsProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

// =====================================================================
// ペット詳細（BottomSheet、タブ形式）
// =====================================================================

class _PetDetailSheet extends StatelessWidget {
  const _PetDetailSheet({required this.pet, required this.ref});

  final Pet pet;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // ハンドル
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // ヘッダー（ペット名）
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: pet.photoPath != null && File(pet.photoPath!).existsSync()
                        ? FileImage(File(pet.photoPath!))
                        : null,
                    child: pet.photoPath != null && File(pet.photoPath!).existsSync()
                        ? null
                        : Icon(_speciesIcon(pet.species), color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(pet.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  // 編集ボタン
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.grey),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      // 詳細シートを閉じてから編集シートを開く
                      await Future<void>.delayed(const Duration(milliseconds: 200));
                      if (!context.mounted) return;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _PetFormSheet(ref: ref, pet: pet),
                      );
                    },
                  ),
                  // 削除ボタン
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
            ),
            // タブバー
            TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: '基本情報'),
                Tab(text: '健康記録'),
              ],
            ),
            // タブ内容
            Expanded(
              child: Consumer(
                builder: (context, tabRef, _) {
                  return TabBarView(
                    children: [
                      _BasicInfoTab(pet: pet),
                      _HealthRecordTab(petId: pet.id!, ref: tabRef),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 削除確認ダイアログ
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ペットを削除'),
        content: Text('「${pet.name}」を削除しますか？\n健康記録もすべて消えます。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('やめとく')),
          TextButton(
            onPressed: () async {
              await DatabaseService().deletePet(pet.id!);
              ref.invalidate(petsProvider);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop(); // ダイアログを閉じる
              if (!context.mounted) return;
              Navigator.of(context).pop(); // 詳細シートを閉じる
            },
            child: const Text('削除する', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// 基本情報タブ
// =====================================================================

class _BasicInfoTab extends StatelessWidget {
  const _BasicInfoTab({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _infoRow('種別', pet.species),
        if (pet.breed != null) _infoRow('品種', pet.breed!),
        if (pet.birthDate != null) _infoRow('生年月日', _dateFormat.format(pet.birthDate!)),
        if (pet.gender != null) _infoRow('性別', pet.gender!),
        if (pet.hospitalName != null) _infoRow('かかりつけ病院', pet.hospitalName!),
        if (pet.microchipNumber != null) _infoRow('マイクロチップ番号', pet.microchipNumber!),
        if (pet.insuranceInfo != null) _infoRow('保険情報', pet.insuranceInfo!),
        if (pet.memo != null) ...[
          const SizedBox(height: 12),
          const Text('メモ', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(pet.memo!),
          ),
        ],
      ],
    );
  }

  /// 情報行ウィジェット
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}

// =====================================================================
// 健康記録タブ（ワクチン + 体重 + その他を統合）
// =====================================================================

/// 統合リスト用の記録アイテム
class _HealthRecord implements Comparable<_HealthRecord> {
  final String type; // 'vaccine', 'weight', 'other'
  final String title;
  final String? subtitle;
  final DateTime date;
  final int id;
  final String table; // 削除時にどのテーブルか判別

  const _HealthRecord({
    required this.type,
    required this.title,
    this.subtitle,
    required this.date,
    required this.id,
    required this.table,
  });

  @override
  int compareTo(_HealthRecord other) => other.date.compareTo(date); // 新しい順

  Widget buildIcon(Color color) => switch (type) {
    'weight' => _WeightIcon(color: color, size: 24),
    'vaccine' => Icon(Icons.vaccines, color: color),
    _ => Icon(Icons.note_alt_outlined, color: color),
  };
}

enum _RecordFilter { all, vaccine, weight, other }

class _HealthRecordTab extends StatefulWidget {
  const _HealthRecordTab({required this.petId, required this.ref});

  final int petId;
  final WidgetRef ref;

  @override
  State<_HealthRecordTab> createState() => _HealthRecordTabState();
}

class _HealthRecordTabState extends State<_HealthRecordTab> {
  _RecordFilter _filter = _RecordFilter.all;

  @override
  Widget build(BuildContext context) {
    final vaccAsync = widget.ref.watch(vaccinationsProvider(widget.petId));
    final weightAsync = widget.ref.watch(weightLogsProvider(widget.petId));

    return vaccAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
      data: (vaccRecords) => weightAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (weightLogs) {
          // 統合リスト構築
          final allRecords = <_HealthRecord>[];

          for (final r in vaccRecords) {
            final date = DateTime.tryParse(r['date'] as String? ?? '');
            if (date == null) continue;
            final nextDate = r['next_date'] != null
                ? DateTime.tryParse(r['next_date'] as String)
                : null;
            allRecords.add(_HealthRecord(
              type: 'vaccine',
              title: r['vaccine_name'] as String? ?? '',
              subtitle: [
                '記録日: ${_dateFormat.format(date)}',
                if (nextDate != null) '次回: ${_dateFormat.format(nextDate)}',
              ].join('  '),
              date: date,
              id: r['id'] as int,
              table: 'vaccinations',
            ));
          }

          for (final r in weightLogs) {
            final date = DateTime.tryParse(r['date'] as String? ?? '');
            if (date == null) continue;
            final weight = r['weight'] as num?;
            allRecords.add(_HealthRecord(
              type: 'weight',
              title: '${weight ?? '-'} kg',
              subtitle: _dateFormat.format(date),
              date: date,
              id: r['id'] as int,
              table: 'weight_logs',
            ));
          }

          allRecords.sort();

          // フィルタ適用
          final filtered = _filter == _RecordFilter.all
              ? allRecords
              : allRecords.where((r) => r.type == _filter.name).toList();

          return Column(
            children: [
              // セグメントコントロール
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SegmentedButton<_RecordFilter>(
                  segments: const [
                    ButtonSegment(value: _RecordFilter.all, label: Text('すべて')),
                    ButtonSegment(value: _RecordFilter.vaccine, label: Text('ワクチン')),
                    ButtonSegment(value: _RecordFilter.weight, label: Text('体重')),
                    ButtonSegment(value: _RecordFilter.other, label: Text('その他')),
                  ],
                  selected: {_filter},
                  showSelectedIcon: false,
                  onSelectionChanged: (set) => setState(() => _filter = set.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary.withValues(alpha: 0.15);
                      }
                      return null;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) return AppColors.primary;
                      return Colors.black54;
                    }),
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
              // 追加ボタン
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddRecord(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('記録を追加'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              // リスト
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('記録がまだありません', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = filtered[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: r.buildIcon(AppColors.primary),
                            title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: r.subtitle != null
                                ? Text(r.subtitle!, style: const TextStyle(fontSize: 12))
                                : null,
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey.shade400),
                              onPressed: () async {
                                if (r.table == 'vaccinations') {
                                  await DatabaseService().deleteVaccination(r.id);
                                  widget.ref.invalidate(vaccinationsProvider(widget.petId));
                                } else {
                                  await DatabaseService().deleteWeightLog(r.id);
                                  widget.ref.invalidate(weightLogsProvider(widget.petId));
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 記録追加 — まず種類を選択
  void _showAddRecord(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('記録の種類を選択', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.vaccines, color: AppColors.primary),
              title: const Text('ワクチン・健診'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showAddVaccination(context);
              },
            ),
            ListTile(
              leading: const _WeightIcon(color: AppColors.primary, size: 24),
              title: const Text('体重'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showAddWeight(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_alt_outlined, color: AppColors.primary),
              title: const Text('その他（通院・メモなど）'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showAddOther(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// ワクチン・健診の追加
  void _showAddVaccination(BuildContext context) {
    final nameCtrl = TextEditingController();
    DateTime recordDate = DateTime.now();
    DateTime? nextDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('ワクチン・健診を追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '記録名',
                    hintText: '例: 混合ワクチン、狂犬病、健康診断',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _DatePickerField(
                  label: '記録日',
                  date: recordDate,
                  onChanged: (d) => setDialogState(() => recordDate = d),
                ),
                const SizedBox(height: 12),
                _DatePickerField(
                  label: '次回予定日（任意）',
                  date: nextDate,
                  optional: true,
                  onChanged: (d) => setDialogState(() => nextDate = d),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('キャンセル')),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await DatabaseService().insertVaccination({
                  'pet_id': widget.petId,
                  'vaccine_name': nameCtrl.text.trim(),
                  'date': recordDate.toIso8601String(),
                  if (nextDate != null) 'next_date': nextDate!.toIso8601String(),
                });
                widget.ref.invalidate(vaccinationsProvider(widget.petId));
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 体重の追加
  void _showAddWeight(BuildContext context) {
    final weightCtrl = TextEditingController();
    DateTime logDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('体重を記録'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '体重 (kg)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                _DatePickerField(
                  label: '記録日',
                  date: logDate,
                  onChanged: (d) => setDialogState(() => logDate = d),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('キャンセル')),
            TextButton(
              onPressed: () async {
                final w = double.tryParse(weightCtrl.text.trim());
                if (w == null || w <= 0) return;
                await DatabaseService().insertWeightLog({
                  'pet_id': widget.petId,
                  'weight': w,
                  'date': logDate.toIso8601String(),
                });
                widget.ref.invalidate(weightLogsProvider(widget.petId));
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// その他の記録（vaccinationsテーブルに保存）
  void _showAddOther(BuildContext context) {
    final nameCtrl = TextEditingController();
    DateTime recordDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('記録を追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '記録名',
                    hintText: '例: 通院、トリミング、爪切り',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _DatePickerField(
                  label: '記録日',
                  date: recordDate,
                  onChanged: (d) => setDialogState(() => recordDate = d),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('キャンセル')),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await DatabaseService().insertVaccination({
                  'pet_id': widget.petId,
                  'vaccine_name': nameCtrl.text.trim(),
                  'date': recordDate.toIso8601String(),
                });
                widget.ref.invalidate(vaccinationsProvider(widget.petId));
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 日付ピッカーフィールド（CupertinoDatePicker スクロール式）
// =====================================================================

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onChanged,
    this.optional = false,
  });

  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.calendar_today, size: 20),
            suffixIcon: optional && date != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {},
                  )
                : null,
          ),
          controller: TextEditingController(
            text: date != null ? _dateFormat.format(date!) : (optional ? '未設定' : ''),
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    DateTime tempDate = date ?? DateTime.now();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              // ヘッダー
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('キャンセル'),
                    ),
                    Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        onChanged(tempDate);
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('決定'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // CupertinoDatePicker
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: tempDate,
                  minimumDate: DateTime(2000),
                  maximumDate: DateTime(2035),
                  onDateTimeChanged: (d) => tempDate = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// おもりアイコン（カスタム描画）
// =====================================================================

class _WeightIcon extends StatelessWidget {
  const _WeightIcon({required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WeightIconPainter(color: color)),
    );
  }
}

class _WeightIconPainter extends CustomPainter {
  final Color color;
  _WeightIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 上部の輪っか（リング）
    final ringCX = w * 0.5;
    final ringCY = h * 0.18;
    final ringR = w * 0.12;
    canvas.drawCircle(Offset(ringCX, ringCY), ringR, paint);
    canvas.drawCircle(
      Offset(ringCX, ringCY),
      ringR * 0.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // 台形の本体
    final bodyTop = h * 0.26;
    final bodyBottom = h * 0.92;
    final topLeft = w * 0.22;
    final topRight = w * 0.78;
    final bottomLeft = w * 0.08;
    final bottomRight = w * 0.92;
    final cornerR = w * 0.04;

    final path = Path()
      ..moveTo(topLeft + cornerR, bodyTop)
      ..lineTo(topRight - cornerR, bodyTop)
      ..arcToPoint(Offset(topRight, bodyTop + cornerR),
          radius: Radius.circular(cornerR))
      ..lineTo(bottomRight - cornerR, bodyBottom - cornerR)
      ..arcToPoint(Offset(bottomRight, bodyBottom),
          radius: Radius.circular(cornerR))
      ..lineTo(bottomLeft, bodyBottom)
      ..arcToPoint(Offset(bottomLeft + cornerR, bodyBottom - cornerR),
          radius: Radius.circular(cornerR))
      ..lineTo(topLeft, bodyTop + cornerR)
      ..arcToPoint(Offset(topLeft + cornerR, bodyTop),
          radius: Radius.circular(cornerR))
      ..close();

    canvas.drawPath(path, paint);

    // 台形内に「kg」テキスト
    final textStyle = ui.TextStyle(
      color: Colors.white,
      fontSize: h * 0.28,
      fontWeight: FontWeight.bold,
    );
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
      ..pushStyle(textStyle)
      ..addText('kg');
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: w));
    final textY = (bodyTop + bodyBottom) / 2 - paragraph.height / 2;
    canvas.drawParagraph(paragraph, Offset(0, textY));
  }

  @override
  bool shouldRepaint(covariant _WeightIconPainter old) => old.color != color;
}

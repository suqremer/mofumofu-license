import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/license_card.dart';
import '../models/license_template.dart';
import '../providers/database_provider.dart';
import '../services/database_service.dart';
import '../services/license_composer.dart';
import '../theme/colors.dart';
import '../widgets/banner_ad_widget.dart';

/// 並び替えオプション
enum SortOption {
  newest('新しい順'),
  oldest('古い順'),
  byPet('ペット別');

  final String label;
  const SortOption(this.label);
}

/// 画面6: コレクション（作成済み免許証の一覧）
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  SortOption _sortOption = SortOption.newest;
  bool _selectMode = false;
  final Set<int> _selectedIds = {};

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('まとめて削除'),
        content: Text('$count件の免許証を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        for (final id in _selectedIds) {
          await DatabaseService().deleteLicense(id);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('削除中にエラーが発生しました: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      ref.invalidate(licensesProvider);
      ref.invalidate(licenseCountProvider);
      _exitSelectMode();
    }
  }

  /// 選択中の免許証をまとめてカメラロールに保存
  Future<void> _saveSelectedToGallery() async {
    final licenses = ref.read(licensesProvider).valueOrNull ?? [];
    final selected = licenses.where(
      (c) => c.id != null && _selectedIds.contains(c.id),
    ).toList();

    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      await Gal.requestAccess();
    }

    int saved = 0;
    for (final card in selected) {
      final path = card.savedImagePath;
      if (path == null) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        await Gal.putImage(path, album: 'うちの子免許証');
        saved++;
      } on GalException {
        // skip failed
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$saved件をカメラロールに保存しました！'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _exitSelectMode();
  }

  /// 並び替えを適用
  List<LicenseCard> _sortLicenses(List<LicenseCard> licenses) {
    final sorted = List<LicenseCard>.from(licenses);
    switch (_sortOption) {
      case SortOption.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldest:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.byPet:
        sorted.sort((a, b) {
          final cmp = a.petName.compareTo(b.petName);
          if (cmp != 0) return cmp;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final licensesAsync = ref.watch(licensesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _selectMode
            ? Text('${_selectedIds.length}件選択中')
            : const Text('コレクション'),
        backgroundColor: AppColors.background,
        elevation: 0.5,
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectMode,
              )
            : null,
        actions: _selectMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'すべて選択',
                  onPressed: () {
                    final licenses = licensesAsync.valueOrNull ?? [];
                    setState(() {
                      if (_selectedIds.length == licenses.length) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.addAll(
                          licenses.where((c) => c.id != null).map((c) => c.id!),
                        );
                      }
                    });
                  },
                ),
              ]
            : null,
      ),
      bottomNavigationBar: _selectMode && _selectedIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveSelectedToGallery,
                        icon: const Icon(Icons.save_alt),
                        label: Text('${_selectedIds.length}件を保存'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete),
                        label: Text('${_selectedIds.length}件を削除'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: licensesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(licensesProvider),
        ),
        data: (licenses) {
          if (licenses.isEmpty) return const _EmptyView();
          final sorted = _sortLicenses(licenses);
          return _buildContent(sorted);
        },
      ),
    );
  }

  Widget _buildContent(List<LicenseCard> licenses) {
    return Column(
      children: [
        // ヘッダー: 枚数カウント + 並び替え
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.collections,
                size: 20,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Text(
                '${licenses.length}枚の免許証',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              // 並び替えボタン
              PopupMenuButton<SortOption>(
                initialValue: _sortOption,
                onSelected: (value) =>
                    setState(() => _sortOption = value),
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort,
                        size: 18, color: AppColors.textMedium),
                    const SizedBox(width: 4),
                    Text(
                      _sortOption.label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMedium),
                    ),
                  ],
                ),
                itemBuilder: (context) => SortOption.values
                    .map(
                      (opt) => PopupMenuItem(
                        value: opt,
                        child: Row(
                          children: [
                            if (opt == _sortOption)
                              const Icon(Icons.check,
                                  size: 16, color: AppColors.primary)
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            Text(opt.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        // グリッド本体
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: licenses.length,
            itemBuilder: (context, index) {
              final card = licenses[index];
              final isSelected = card.id != null && _selectedIds.contains(card.id);
              return _LicenseCardTile(
                card: card,
                index: index,
                selectMode: _selectMode,
                isSelected: isSelected,
                onTap: () {
                  if (_selectMode) {
                    if (card.id != null) _toggleSelect(card.id!);
                  } else {
                    _showDetailSheet(card);
                  }
                },
                onLongPress: () {
                  if (!_selectMode) {
                    setState(() => _selectMode = true);
                    if (card.id != null) _toggleSelect(card.id!);
                  }
                },
              );
            },
          ),
        ),
        const BannerAdWidget(),
      ],
    );
  }

  /// 詳細ボトムシート: 拡大表示 + 再シェア/削除
  void _showDetailSheet(LicenseCard card) {
    final licenseType = LicenseType.findById(card.licenseType);
    final dateText = DateFormat('yyyy/MM/dd').format(card.createdAt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ドラッグハンドル
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // 免許証画像
            _buildDetailImage(card),
            const SizedBox(height: 16),
            // ペット情報
            Text(
              card.petName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${licenseType.label} / $dateText',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMedium),
            ),
            const SizedBox(height: 20),
            // アクションボタン（上段: 編集+保存+シェア+NFC、下段: 削除）
            Row(
              children: [
                _detailActionButton(
                  icon: Icons.edit_outlined,
                  label: '編集',
                  onTap: () {
                    Navigator.pop(ctx);
                    _editLicense(card);
                  },
                ),
                const SizedBox(width: 8),
                _detailActionButton(
                  icon: Icons.save_alt,
                  label: '保存',
                  onTap: () {
                    Navigator.pop(ctx);
                    _saveToGallery(card);
                  },
                ),
                const SizedBox(width: 8),
                _detailActionButton(
                  icon: Icons.share,
                  label: 'シェア',
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareExistingLicense(card);
                  },
                ),
                const SizedBox(width: 8),
                _detailActionButton(
                  icon: Icons.nfc,
                  label: 'NFC',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/nfc-write', extra: card);
                  },
                ),
                const SizedBox(width: 8),
                _detailActionButton(
                  icon: Icons.local_shipping_outlined,
                  label: '注文',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/order');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showDeleteDialog(card);
              },
              icon: Icon(Icons.delete_outline,
                  size: 16, color: Colors.grey.shade500),
              label: Text('削除',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500)),
            ),
          ],
        ),
      ),
    );
  }

  /// 詳細シートの画像表示
  Widget _buildDetailImage(LicenseCard card) {
    final imagePath = card.savedImagePath ?? card.photoPath;
    final file = File(imagePath);

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return Image.file(file, fit: BoxFit.contain);
          }
          return Container(
            width: double.infinity,
            height: 200,
            color: AppColors.primary.withValues(alpha: 0.08),
            child: Icon(Icons.pets,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.3)),
          );
        },
      ),
    );
  }

  /// 詳細シート用アクションボタン（アイコン上+テキスト下の縦レイアウト）
  Widget _detailActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// 既存免許証を再シェア
  Future<void> _shareExistingLicense(LicenseCard card) async {
    final imagePath = card.savedImagePath;
    if (imagePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('完成画像がありません')),
        );
      }
      return;
    }

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('画像ファイルが見つかりません')),
          );
        }
        return;
      }

      // シェア用正方形画像を生成
      final imageBytes = await file.readAsBytes();
      final shareBytes =
          await LicenseComposer().composeShareImage(imageBytes);
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile =
          File('${tempDir.path}/mofumofu_share_$timestamp.png');
      await tempFile.writeAsBytes(shareBytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'うちの子免許証で免許証を発行したよ！',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('シェアに失敗しました: $e')),
        );
      }
    }
  }

  /// カメラロールに保存
  Future<void> _saveToGallery(LicenseCard card) async {
    final imagePath = card.savedImagePath;
    if (imagePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('完成画像がありません')),
        );
      }
      return;
    }

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('画像ファイルが見つかりません')),
          );
        }
        return;
      }

      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      await Gal.putImage(imagePath,
          album: 'うちの子免許証');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('カメラロールに保存しました！'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on GalException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: ${_galErrorMessage(e)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 既存免許証を編集（写真以外を変更可能）
  void _editLicense(LicenseCard card) {
    context.push('/create/info', extra: {
      'editId': card.id,
      'photoPath': card.photoPath,
      'petName': card.petName,
      'species': card.species,
      'breed': card.breed ?? '',
      'birthDate': card.birthDate?.toIso8601String(),
      'gender': card.gender,
      'specialty': card.specialty ?? '',
      'createdAt': card.createdAt,
      'templateType': card.templateType,
      'frameColor': card.frameColor,
      'costumeId': card.costumeId,
    });
  }

  /// 削除確認ダイアログ
  Future<void> _showDeleteDialog(LicenseCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('免許証を削除'),
        content: Text('${card.petName}の免許証を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (card.id != null) {
        await DatabaseService().deleteLicense(card.id!);
        ref.invalidate(licensesProvider);
      }
    }
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

/// 空状態ビュー
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets,
                size: 96,
                color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            const Text(
              'まだ免許証がありません',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ペットの免許証を作ってみよう！',
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push('/create/photo'),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('免許証をつくる'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// エラー状態ビュー
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'データの読み込みに失敗しました',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('もう一度試す'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 個々の免許証カードタイル（スタガードスライドインアニメーション付き）
class _LicenseCardTile extends StatefulWidget {
  const _LicenseCardTile({
    required this.card,
    required this.onTap,
    required this.onLongPress,
    required this.index,
    this.selectMode = false,
    this.isSelected = false,
  });

  final LicenseCard card;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int index;
  final bool selectMode;
  final bool isSelected;

  @override
  State<_LicenseCardTile> createState() => _LicenseCardTileState();
}

class _LicenseCardTileState extends State<_LicenseCardTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideX;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideX = Tween<double>(begin: 60.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // スタガード: インデックスに応じて遅延
    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final licenseType = LicenseType.findById(card.licenseType);
    final dateText = DateFormat('yyyy/MM/dd').format(card.createdAt);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(_slideX.value, 0),
        child: Opacity(
          opacity: _opacity.value,
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: widget.isSelected
              ? Border.all(color: AppColors.primary, width: 2.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: _buildImage()),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.petName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        licenseType.label,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12,
                            color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          dateText,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
            if (widget.selectMode)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isSelected ? AppColors.primary : Colors.white,
                    border: Border.all(
                      color: widget.isSelected ? AppColors.primary : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: widget.isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildImage() {
    final imagePath = widget.card.savedImagePath ?? widget.card.photoPath;
    final file = File(imagePath);

    return Container(
      color: AppColors.background,
      child: FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return Image.file(
              file,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, _, _) => _buildPlaceholder(),
            );
          }
          return _buildPlaceholder();
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Center(
        child: Icon(Icons.pets,
            size: 40,
            color: AppColors.primary.withValues(alpha: 0.3)),
      ),
    );
  }
}

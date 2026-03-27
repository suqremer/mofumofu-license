import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// 商品写真のスライドショー定義
class ProductPhoto {
  final String? assetPath;
  final String label;
  final IconData placeholderIcon;

  const ProductPhoto({
    this.assetPath,
    required this.label,
    this.placeholderIcon = Icons.photo_camera,
  });
}

/// PVCカード商品写真一覧
const kCardPhotos = [
  ProductPhoto(assetPath: 'assets/product_photos/card_front.jpg', label: 'カード表面', placeholderIcon: Icons.credit_card),
  ProductPhoto(assetPath: 'assets/product_photos/card_back.jpg', label: 'カード裏面', placeholderIcon: Icons.flip),
  ProductPhoto(assetPath: 'assets/product_photos/card_display.jpg', label: '飾ったイメージ', placeholderIcon: Icons.collections),
];

/// レジンタグ商品写真一覧
const kTagPhotos = [
  ProductPhoto(assetPath: 'assets/product_photos/tag_front.jpg', label: 'タグ表面', placeholderIcon: Icons.pets),
  ProductPhoto(assetPath: 'assets/product_photos/tag_back.jpg', label: 'タグ裏面', placeholderIcon: Icons.flip),
  ProductPhoto(assetPath: 'assets/product_photos/tag_size.jpg', label: 'サイズ感', placeholderIcon: Icons.straighten),
  ProductPhoto(assetPath: 'assets/product_photos/set_overview.jpg', label: 'セット', placeholderIcon: Icons.inventory_2),
];

/// ホーム画面用: カード+タグの全写真
const kAllProductPhotos = [
  ...kCardPhotos,
  ...kTagPhotos,
];

/// 商品写真スライドショーウィジェット
///
/// [photos] に渡した商品写真リストを自動でスライド表示する。
/// 実物写真がまだない場合はプレースホルダーUIを表示。
/// [height] でスライドショーの高さを指定。[compact] で小さめ表示。
class ProductGallery extends StatefulWidget {
  final List<ProductPhoto> photos;
  final double height;
  final bool compact;

  const ProductGallery({
    super.key,
    required this.photos,
    this.height = 200,
    this.compact = false,
  });

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.photos.isEmpty) return;
      final nextPage = (_currentPage + 1) % widget.photos.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildPhotoCard(photo),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // ドットインジケーター
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.photos.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == i ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentPage == i
                    ? AppColors.primary
                    : AppColors.textLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard(ProductPhoto photo) {
    final hasImage = photo.assetPath != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(photo.assetPath!, fit: BoxFit.cover),
                _buildLabel(photo.label),
              ],
            )
          : _buildPlaceholder(photo),
    );
  }

  Widget _buildPlaceholder(ProductPhoto photo) {
    final iconSize = widget.compact ? 36.0 : 48.0;
    final fontSize = widget.compact ? 12.0 : 14.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.secondary.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(photo.placeholderIcon,
              size: iconSize, color: AppColors.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text(
            photo.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '実物写真 準備中',
            style: TextStyle(
              fontSize: widget.compact ? 10.0 : 11.0,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

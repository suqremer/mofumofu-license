import 'dart:io';
import 'package:flutter/material.dart';

import '../theme/colors.dart';

class LicenseCardPreview extends StatelessWidget {
  final String petName;
  final String species;
  final String licenseType;
  final String? photoPath;
  final VoidCallback? onTap;

  static const _gold = Color(0xFFFFD54F);

  const LicenseCardPreview({
    super.key,
    required this.petName,
    required this.species,
    required this.licenseType,
    this.photoPath,
    this.onTap,
  });

  IconData _speciesIcon() {
    return switch (species) {
      '犬' => Icons.pets,
      '猫' => Icons.pets,
      '鳥' => Icons.flutter_dash,
      _ => Icons.emoji_nature,
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shadowColor: AppColors.primary.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 写真 or プレースホルダ
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: photoPath != null
                      ? Image.file(
                          File(photoPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(height: 8),
              // ペット名
              Text(
                petName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // 種別
              Text(
                species,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              // 免許種別バッジ（中央揃え）
              Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    licenseType,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.background,
      child: Icon(
        _speciesIcon(),
        size: 48,
        color: AppColors.primary.withValues(alpha: 0.4),
      ),
    );
  }
}

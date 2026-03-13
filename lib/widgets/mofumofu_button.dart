import 'package:flutter/material.dart';

import '../theme/colors.dart';

enum _ButtonVariant { filled, outlined, text }

class MofumofuButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final _ButtonVariant _variant;

  static const _radius = BorderRadius.all(Radius.circular(16));

  const MofumofuButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : _variant = _ButtonVariant.filled;

  const MofumofuButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : _variant = _ButtonVariant.outlined;

  const MofumofuButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : _variant = _ButtonVariant.text;

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }
    return Text(label);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    return switch (_variant) {
      _ButtonVariant.filled => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: const RoundedRectangleBorder(borderRadius: _radius),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: _buildChild(),
        ),
      _ButtonVariant.outlined => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: const RoundedRectangleBorder(borderRadius: _radius),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: _buildChild(),
        ),
      _ButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: const RoundedRectangleBorder(borderRadius: _radius),
          ),
          child: _buildChild(),
        ),
    };
  }
}

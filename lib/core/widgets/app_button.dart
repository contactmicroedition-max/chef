import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool isLoading;

  Widget get _loadingIndicator => const SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final effectiveChild = isLoading && icon == null
        ? _loadingIndicator
        : child;
    final effectiveIcon = icon == null
        ? null
        : isLoading
        ? _loadingIndicator
        : icon;

    return switch (variant) {
      AppButtonVariant.primary =>
        effectiveIcon == null
            ? FilledButton(onPressed: effectiveOnPressed, child: effectiveChild)
            : FilledButton.icon(
                onPressed: effectiveOnPressed,
                icon: effectiveIcon,
                label: effectiveChild,
              ),
      AppButtonVariant.secondary =>
        effectiveIcon == null
            ? OutlinedButton(
                onPressed: effectiveOnPressed,
                child: effectiveChild,
              )
            : OutlinedButton.icon(
                onPressed: effectiveOnPressed,
                icon: effectiveIcon,
                label: effectiveChild,
              ),
      AppButtonVariant.text => TextButton(
        onPressed: effectiveOnPressed,
        child: effectiveChild,
      ),
    };
  }
}

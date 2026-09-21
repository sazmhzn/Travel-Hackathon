import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_sizes.dart';

/// Press-and-hold confirmation control. Used for irreversible or emergency
/// actions (e.g. triggering rescue mode) so a stray tap cannot fire them.
///
/// The fill sweeps left→right over [holdDuration]; releasing early cancels.
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.icon,
    this.holdDuration = const Duration(milliseconds: 1500),
    this.color,
    this.enabled = true,
    this.holdLabel,
  });

  final String label;

  /// Shown while holding, e.g. "Keep holding…".
  final String? holdLabel;
  final VoidCallback onConfirmed;
  final IconData? icon;
  final Duration holdDuration;
  final Color? color;
  final bool enabled;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener(_onStatus);

  bool _confirmed = false;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_confirmed) {
      _confirmed = true;
      HapticFeedback.mediumImpact();
      widget.onConfirmed();
      _controller.reset();
      _confirmed = false;
    }
  }

  void _start() {
    if (!widget.enabled) return;
    _controller.forward();
  }

  void _cancel() {
    if (!widget.enabled) return;
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final color = widget.color ?? colors.danger;
    final held = _controller.value >= 0.5;
    final foreground = held ? colors.onDanger : color;
    final label = _controller.isAnimating ? (widget.holdLabel ?? widget.label) : widget.label;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: '${widget.label}. Press and hold to confirm.',
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _cancel(),
        onTapCancel: _cancel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Container(
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: widget.enabled ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _controller.value,
                      heightFactor: 1,
                      child: ColoredBox(color: color),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 18, color: foreground),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.labelLarge?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

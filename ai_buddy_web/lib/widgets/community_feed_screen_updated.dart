import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/community_provider.dart';
import './app_back_button.dart';
import '../services/analytics_service.dart' show logAnalyticsEvent;
import '../core/utils/size_utils.dart';
import '../theme/theme_helper.dart';
import '../theme/text_style_helper.dart';

// ... [Previous widget imports and other code remain the same until _ReactionChip]

class _ReactionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  _ReactionChipState createState() => _ReactionChipState();
}

class _ReactionChipState extends State<_ReactionChip> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        widget.onTap();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return FocusableActionDetector(
      focusNode: _focusNode,
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
      },
      mouseCursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        label: widget.count > 0
            ? '${widget.label}, ${widget.count}'
            : widget.label,
        child: Container(
          decoration: BoxDecoration(
            color: _isFocused
                ? color.primary.withOpacity(0.1)
                : color.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isFocused ? color.primary : const Color(0xFFE0E6EE),
              width: _isFocused ? 2.0 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: color.primary.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 16, color: color.primary),
                    const SizedBox(width: 6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: color.primary,
                        fontWeight:
                            _isFocused ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (widget.count > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${widget.count}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _isFocused ? color.primary : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ... [Rest of the file remains the same]

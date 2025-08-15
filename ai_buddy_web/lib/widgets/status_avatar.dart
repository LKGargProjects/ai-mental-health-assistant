import 'package:flutter/material.dart';
import '../config/profile_config.dart';

/// Renders an avatar with an optional presence/status badge.
class StatusAvatar extends StatelessWidget {
  const StatusAvatar({
    super.key,
    required this.name,
    this.imageAsset,
    this.size = 40,
    this.status = PresenceStatus.none,
    this.showStatus = true,
    this.semanticLabel,
  });

  final String name;
  final String? imageAsset;
  final double size;
  final PresenceStatus status;
  final bool showStatus;
  final String? semanticLabel;

  String get _initials {
    final parts = name.trim().split(RegExp(r"\s+"));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.last : '';
    final init = (first.isNotEmpty ? first[0] : '') + (last.isNotEmpty ? last[0] : '');
    return init.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final statusSize = (size * 0.22).clamp(8, 16).toDouble();
    final surface = Theme.of(context).colorScheme.surface;
    final label = semanticLabel ?? _buildSemanticLabel();

    Widget avatar;
    if (imageAsset != null && imageAsset!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundImage: AssetImage(imageAsset!),
        backgroundColor: Colors.transparent,
      );
    } else {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.indigo.shade100,
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.indigo.shade800,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.36,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Semantics(
      label: label,
      image: true,
      child: SizedBox(
        height: size,
        width: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: avatar),
            if (showStatus && status != PresenceStatus.none)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  height: statusSize,
                  width: statusSize,
                  decoration: BoxDecoration(
                    color: status.color(),
                    shape: BoxShape.circle,
                    border: Border.all(color: surface, width: (size * 0.03).clamp(1.5, 3.0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _buildSemanticLabel() {
    switch (status) {
      case PresenceStatus.online:
        return '$name, online';
      case PresenceStatus.idle:
        return '$name, idle';
      case PresenceStatus.offline:
        return '$name, offline';
      case PresenceStatus.none:
        return name;
    }
  }
}

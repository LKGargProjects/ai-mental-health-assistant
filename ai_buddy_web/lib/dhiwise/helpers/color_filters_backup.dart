/// Backup of color filter helpers previously used in Reminder card image.
/// Not referenced in code; kept for future design experiments.
library color_filters_backup;

/// Returns a 4x5 saturation color matrix suitable for ColorFilter.matrix.
///
/// s = 1.0 keeps original saturation.
/// s > 1.0 increases saturation.
/// s < 1.0 decreases saturation.
List<double> saturationMatrix(double s) {
  final double a = 0.213 * (1 - s) + s;
  final double b = 0.715 * (1 - s);
  final double c = 0.072 * (1 - s);
  return <double>[
    a, b, c, 0, 0,
    0.213 * (1 - s), 0.715 * (1 - s) + s, 0.072 * (1 - s), 0, 0,
    0.213 * (1 - s), 0.715 * (1 - s), 0.072 * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

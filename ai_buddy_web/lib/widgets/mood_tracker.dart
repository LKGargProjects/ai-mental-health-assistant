import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/mood_provider.dart';
import '../models/mood_entry.dart';

enum ViewMode { daily, all }

class MoodTrackerWidget extends StatefulWidget {
  const MoodTrackerWidget({super.key});

  @override
  State<MoodTrackerWidget> createState() => _MoodTrackerWidgetState();
}

class _MoodTrackerWidgetState extends State<MoodTrackerWidget> {
  ViewMode _mode = ViewMode.daily; // default to Daily trend (aggregated)
  static const bool _enableCheckinsExpand = false; // feature toggle (hidden for now)
  bool _showLatestDayDetails = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<MoodProvider>(
      builder: (context, moodProvider, child) {
        final hasEntries = moodProvider.moodEntries.isNotEmpty;
        // Do not block UI on initial load; show input immediately

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Show error banner only when there are no entries to display.
              if (moodProvider.error != null && !hasEntries) ...[
                _buildErrorBanner(context, moodProvider),
                const SizedBox(height: 12),
              ],
              _buildMoodInput(context, moodProvider),
              const SizedBox(height: 16),
              // Toggle between Daily (aggregated) and All check-ins
              if (hasEntries) ...[
                _buildViewToggle(context),
                const SizedBox(height: 8),
                _buildCheckinsInfo(context, moodProvider),
                const SizedBox(height: 8),
              ],
              if (moodProvider.moodEntries.isNotEmpty) ...[
                _buildMoodChart(context, moodProvider, _mode),
                if (_mode == ViewMode.daily) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Avg per day',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.7),
                            fontFamily: 'Inter',
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
                _buildMoodStats(context, moodProvider),
              ] else ...[
                _buildEmptyMoodPlaceholder(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner(BuildContext context, MoodProvider moodProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              moodProvider.error ?? 'Something went wrong',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontFamily: 'Inter',
              ),
            ),
          ),
          TextButton(
            onPressed: () => moodProvider.reload(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMoodPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.show_chart_outlined,
                  size: 40,
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'No mood entries yet',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  "Log today's mood to see your trend",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoodInput(BuildContext context, MoodProvider moodProvider) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How are you feeling today?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final moodLevel = index + 1;
                final entry = MoodEntry(moodLevel: moodLevel);
                return IconButton(
                  onPressed: () => _showMoodDialog(context, moodProvider, moodLevel),
                  icon: Text(
                    entry.moodEmoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                  tooltip: entry.moodDescription,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    final isDaily = _mode == ViewMode.daily;
    return Align(
      alignment: Alignment.centerRight,
      child: ToggleButtons(
        isSelected: [isDaily, !isDaily],
        onPressed: (index) {
          setState(() {
            _mode = index == 0 ? ViewMode.daily : ViewMode.all;
          });
        },
        constraints: const BoxConstraints(minHeight: 36, minWidth: 56),
        borderRadius: BorderRadius.circular(8),
        selectedBorderColor: Theme.of(context).colorScheme.primary,
        selectedColor: Theme.of(context).colorScheme.primary,
        fillColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        children: const [
          Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text('Daily')),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text('All')),
        ],
      ),
    );
  }

  Widget _buildCheckinsInfo(BuildContext context, MoodProvider moodProvider) {
    if (_mode != ViewMode.daily) return const SizedBox.shrink();
    final map = moodProvider.moodEntriesByDate;
    if (map.isEmpty) return const SizedBox.shrink();
    final days = map.keys.toList()..sort();
    final lastDay = days.last;
    final count = map[lastDay]?.length ?? 0;
    if (count <= 1) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context);
    final dateLocale = (locale.countryCode?.toUpperCase() == 'IN') ? 'en_GB' : locale.toLanguageTag();
    final label = '$count check-ins on ${DateFormat.MMMd(dateLocale).format(lastDay)}';
    final dayEntries = List<MoodEntry>.from(map[lastDay] ?? const <MoodEntry>[])..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text(label)),
        ),
        if (_enableCheckinsExpand)
          TextButton(
            onPressed: () {
              setState(() {
                _showLatestDayDetails = !_showLatestDayDetails;
              });
            },
            child: Text(_showLatestDayDetails ? 'Hide check-ins' : 'View check-ins'),
          ),
        if (_enableCheckinsExpand && _showLatestDayDetails)
          Card(
            elevation: 1.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Column(
                children: dayEntries.map((e) {
                  final t = e.timestamp.toLocal();
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    leading: Text(e.moodEmoji, style: const TextStyle(fontSize: 20)),
                    title: Text(DateFormat('HH:mm').format(t)),
                    subtitle: (e.note != null && e.note!.trim().isNotEmpty)
                        ? Text(e.note!.trim())
                        : null,
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMoodChart(BuildContext context, MoodProvider moodProvider, ViewMode mode) {
    // Prepare data and labels based on selected mode
    List<String> labels = <String>[];
    List<FlSpot> spots = <FlSpot>[];
    final locale = Localizations.localeOf(context);
    final dateLocale = (locale.countryCode?.toUpperCase() == 'IN') ? 'en_GB' : locale.toLanguageTag();

    if (mode == ViewMode.daily) {
      final map = moodProvider.moodEntriesByDate;
      if (map.isEmpty) return const SizedBox.shrink();
      final days = map.keys.toList()..sort();
      for (int i = 0; i < days.length; i++) {
        final d = days[i];
        final list = map[d] ?? const <MoodEntry>[];
        if (list.isEmpty) continue;
        final sum = list.fold<int>(0, (s, e) => s + e.moodLevel);
        final avg = sum / list.length;
        labels.add(DateFormat.MMMd(dateLocale).format(d));
        spots.add(FlSpot(i.toDouble(), avg.toDouble()));
      }
    } else {
      final entries = moodProvider.moodEntries;
      if (entries.isEmpty) return const SizedBox.shrink();
      // If all entries are the same day, show time-of-day for clarity; otherwise show date.
      final first = entries.first.timestamp.toLocal();
      final sameDay = entries.every((e) {
        final t = e.timestamp.toLocal();
        return t.year == first.year && t.month == first.month && t.day == first.day;
      });
      labels = entries
          .map((e) => sameDay
              ? DateFormat('HH:mm').format(e.timestamp.toLocal())
              : DateFormat.MMMd(dateLocale).format(e.timestamp.toLocal()))
          .toList();
      spots = entries.asMap().entries
          .map((entry) => FlSpot(entry.key.toDouble(), entry.value.moodLevel.toDouble()))
          .toList();
    }

    if (labels.isEmpty || spots.isEmpty) return const SizedBox.shrink();

    // Determine tick density for bottom axis to avoid clutter.
    final len = labels.length;
    final step = len <= 6 ? 1 : (len / 6).ceil();

    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value < 1 || value > 5) return const Text('');
                      return Text(MoodEntry(moodLevel: value.toInt()).moodEmoji);
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= labels.length) return const Text('');
                      // Only show a subset of labels to reduce clutter
                      if (i == 0 || i == labels.length - 1 || i % step == 0) {
                        return Text(labels[i]);
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: labels.length.toDouble() - 1,
              minY: 1,
              maxY: 5,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: spots.length > 2,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: spots.length > 1,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoodStats(BuildContext context, MoodProvider moodProvider) {
    final entries = moodProvider.moodEntries;
    if (entries.isEmpty) return const SizedBox.shrink();

    final averageMood = moodProvider.averageMood;
    final latestMood = entries.last;

    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mood Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  'Current',
                  latestMood.moodEmoji,
                  latestMood.moodDescription,
                ),
                _buildStatItem(
                  context,
                  'Average',
                  MoodEntry(moodLevel: averageMood.round()).moodEmoji,
                  averageMood.toStringAsFixed(1),
                ),
                _buildStatItem(
                  context,
                  'Entries',
                  '📊',
                  entries.length.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String emoji,
    String value,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFamily: 'Inter', // Match chat screen font family
          ),
        ),
        const SizedBox(height: 4),
        Text(
          emoji,
          style: const TextStyle(fontSize: 32),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'Inter', // Match chat screen font family
          ),
        ),
      ],
    );
  }

  Future<void> _showMoodDialog(
    BuildContext context,
    MoodProvider moodProvider,
    int moodLevel,
  ) async {
    final noteController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: Row(
          children: [
            Text(
              MoodEntry(moodLevel: moodLevel).moodEmoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 8),
            Text(
              'Feeling ${MoodEntry(moodLevel: moodLevel).moodDescription}',
              style: TextStyle(
                fontFamily: 'Inter', // Match chat screen font family
                fontSize: 18.0, // Keep existing size
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'Add a note (optional)',
            hintText: 'What made you feel this way?',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              moodProvider.addMoodEntry(
                moodLevel,
                note: noteController.text.trim(),
              );
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
} 
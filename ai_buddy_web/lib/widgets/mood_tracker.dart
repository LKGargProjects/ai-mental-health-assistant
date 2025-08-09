import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/mood_provider.dart';
import '../models/mood_entry.dart';

class MoodTrackerWidget extends StatelessWidget {
  const MoodTrackerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MoodProvider>(
      builder: (context, moodProvider, child) {
        if (moodProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (moodProvider.error != null) {
          return Center(
            child: Text(
              moodProvider.error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontFamily: 'Inter', // Match chat screen font family
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildMoodInput(context, moodProvider),
              const SizedBox(height: 16),
              if (moodProvider.moodEntries.isNotEmpty) ...[
                _buildMoodChart(context, moodProvider),
                const SizedBox(height: 16),
                _buildMoodStats(context, moodProvider),
              ],
            ],
          ),
        );
      },
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

  Widget _buildMoodChart(BuildContext context, MoodProvider moodProvider) {
    final entries = moodProvider.moodEntries;
    if (entries.isEmpty) return const SizedBox.shrink();

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
                      if (value >= entries.length) return const Text('');
                      final date = entries[value.toInt()].timestamp;
                      return Text(DateFormat('MM/dd').format(date));
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
              maxX: entries.length.toDouble() - 1,
              minY: 1,
              maxY: 5,
              lineBarsData: [
                LineChartBarData(
                  spots: entries.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      entry.value.moodLevel.toDouble(),
                    );
                  }).toList(),
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
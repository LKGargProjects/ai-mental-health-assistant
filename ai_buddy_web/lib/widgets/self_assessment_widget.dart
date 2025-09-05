import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/progress_provider.dart';

class SelfAssessmentWidget extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onAssessmentSubmitted;

  const SelfAssessmentWidget({
    super.key,
    this.sessionId,
    this.onAssessmentSubmitted,
  });

  @override
  State<SelfAssessmentWidget> createState() => _SelfAssessmentWidgetState();
}

class _SelfAssessmentWidgetState extends State<SelfAssessmentWidget> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  String _selectedMood = 'neutral';
  String _selectedEnergy = 'medium';
  String _selectedSleep = 'fair';
  String _selectedStress = 'medium';
  String _selectedCrisisLevel = ''; // Use empty string instead of null
  String _selectedAnxietyLevel = ''; // Use empty string instead of null

  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _moodOptions = [
    {'value': 'happy', 'label': 'Happy', 'icon': '😊'},
    {'value': 'calm', 'label': 'Calm', 'icon': '😌'},
    {'value': 'neutral', 'label': 'Neutral', 'icon': '😐'},
    {'value': 'anxious', 'label': 'Anxious', 'icon': '😰'},
    {'value': 'sad', 'label': 'Sad', 'icon': '😢'},
    {'value': 'angry', 'label': 'Angry', 'icon': '😠'},
    {'value': 'depressed', 'label': 'Depressed', 'icon': '😞'},
    {'value': 'mixed', 'label': 'Mixed', 'icon': '😕'},
  ];

  final List<Map<String, dynamic>> _levelOptions = [
    {'value': 'very_low', 'label': 'Very Low'},
    {'value': 'low', 'label': 'Low'},
    {'value': 'medium', 'label': 'Medium'},
    {'value': 'high', 'label': 'High'},
    {'value': 'very_high', 'label': 'Very High'},
  ];

  final List<Map<String, dynamic>> _sleepOptions = [
    {'value': 'excellent', 'label': 'Excellent'},
    {'value': 'good', 'label': 'Good'},
    {'value': 'fair', 'label': 'Fair'},
    {'value': 'poor', 'label': 'Poor'},
    {'value': 'excessive', 'label': 'Excessive'},
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitAssessment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final apiService = ApiService();

      // Build assessment data with proper null handling
      final Map<String, dynamic> assessmentData = {
        'mood': _selectedMood,
        'energy': _selectedEnergy,
        'sleep': _selectedSleep,
        'stress': _selectedStress,
        'notes': _notesController.text.trim(),
      };

      // Only add optional fields if they have valid values (not null or empty)
      if (_selectedCrisisLevel.isNotEmpty) {
        assessmentData['crisis_level'] = _selectedCrisisLevel;
      }

      if (_selectedAnxietyLevel.isNotEmpty) {
        assessmentData['anxiety_level'] = _selectedAnxietyLevel;
      }

      if (kDebugMode) {
        debugPrint('📤 Sending self-assessment data: $assessmentData');
      }
      final response = await apiService.submitSelfAssessment(assessmentData);
      if (kDebugMode) debugPrint('✅ Self-assessment response: $response');

      // Parse XP and daily limit flags
      final int xpAwarded = ((response['xp_awarded']) is num)
          ? (response['xp_awarded'] as num).toInt()
          : 0;
      final bool alreadyCompletedToday = response['already_completed_today'] == true;

      // Apply XP to progress provider
      if (xpAwarded > 0 && mounted) {
        Provider.of<ProgressProvider>(context, listen: false).addXp(xpAwarded);
      }

      if (mounted) {
        // Contextual feedback
        final snackText = alreadyCompletedToday
            ? 'You\'ve already completed today\'s check-in. No extra XP awarded.'
            : (xpAwarded > 0
                ? 'Assessment submitted! +$xpAwarded XP'
                : 'Assessment submitted successfully.');
        final color = alreadyCompletedToday
            ? Colors.orange
            : Colors.green;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackText),
            backgroundColor: color,
          ),
        );

        // Reset form
        _formKey.currentState!.reset();
        _notesController.clear();
        setState(() {
          _selectedMood = 'neutral';
          _selectedEnergy = 'medium';
          _selectedSleep = 'fair';
          _selectedStress = 'medium';
          _selectedCrisisLevel = '';
          _selectedAnxietyLevel = '';
        });

        widget.onAssessmentSubmitted?.call();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Self-assessment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting assessment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSelectionGrid({
    required String title,
    required List<Map<String, dynamic>> options,
    required String selectedValue,
    required Function(String) onChanged,
    bool showIcons = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            // More columns for better space utilization
            int cols = w > 400
                ? 6
                : w > 350
                ? 5
                : 4;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                mainAxisExtent: showIcons
                    ? 50
                    : 40, // Smaller height, especially for non-emoji items
              ),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = selectedValue == option['value'];

                return GestureDetector(
                  onTap: () => onChanged(option['value']),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300]!,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 2,
                    ),
                    child: Center(
                      child: showIcons && option['icon'] != null
                          ? Text(
                              option['icon'],
                              style: const TextStyle(
                                fontSize: 22,
                              ), // Keep emoji size
                              textAlign: TextAlign.center,
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 2,
                              ),
                              child: Text(
                                option['label'],
                                style: TextStyle(
                                  fontSize:
                                      11, // Slightly larger text for better readability
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  height: 1.0,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How are you feeling today?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Mood Selection
            _buildSelectionGrid(
              title: 'Mood',
              options: _moodOptions,
              selectedValue: _selectedMood,
              onChanged: (value) => setState(() => _selectedMood = value),
              showIcons: true,
            ),

            // Energy Level
            _buildSelectionGrid(
              title: 'Energy Level',
              options: _levelOptions,
              selectedValue: _selectedEnergy,
              onChanged: (value) => setState(() => _selectedEnergy = value),
            ),

            // Sleep Quality
            _buildSelectionGrid(
              title: 'Sleep Quality',
              options: _sleepOptions,
              selectedValue: _selectedSleep,
              onChanged: (value) => setState(() => _selectedSleep = value),
            ),

            // Stress Level
            _buildSelectionGrid(
              title: 'Stress Level',
              options: _levelOptions,
              selectedValue: _selectedStress,
              onChanged: (value) => setState(() => _selectedStress = value),
            ),

            // Crisis Level (Optional)
            const Text(
              'Crisis Level (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedCrisisLevel.isEmpty
                    ? null
                    : _selectedCrisisLevel,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select crisis level (if applicable)',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('None', overflow: TextOverflow.ellipsis),
                  ),
                  ..._levelOptions.map(
                    (option) => DropdownMenuItem<String>(
                      value: option['value'] as String,
                      child: Text(
                        option['label'],
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedCrisisLevel = value ?? ''),
              ),
            ),
            const SizedBox(height: 16),

            // Anxiety Level (Optional)
            const Text(
              'Anxiety Level (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedAnxietyLevel.isEmpty
                    ? null
                    : _selectedAnxietyLevel,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select anxiety level (if applicable)',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('None', overflow: TextOverflow.ellipsis),
                  ),
                  ..._levelOptions.map(
                    (option) => DropdownMenuItem<String>(
                      value: option['value'] as String,
                      child: Text(
                        option['label'],
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedAnxietyLevel = value ?? ''),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            const Text(
              'Additional Notes (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Share any additional thoughts or feelings...',
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAssessment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Assessment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../config/api_config.dart';
import '../services/api_service.dart';

class SelfAssessmentWidget extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onAssessmentSubmitted;

  const SelfAssessmentWidget({
    Key? key,
    this.sessionId,
    this.onAssessmentSubmitted,
  }) : super(key: key);

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
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (widget.sessionId != null) 'X-Session-ID': widget.sessionId,
          },
        ),
      );

      // Add logging interceptor
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
          logPrint: (obj) => print('🌐 SELF-ASSESSMENT LOG: $obj'),
        ),
      );

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

      print('📤 Sending self-assessment data: $assessmentData');
      final response = await dio.post(
        '/api/self_assessment',
        data: assessmentData,
      );
      print('✅ Self-assessment response: ${response.data}');

      // If we reach here, the submission was successful
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assessment submitted successfully!'),
            backgroundColor: Colors.green,
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
      print('❌ Self-assessment error: $e');
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            final isSelected = selectedValue == option['value'];

            return GestureDetector(
              onTap: () => onChanged(option['value']),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showIcons && option['icon'] != null)
                      Text(
                        option['icon'],
                        style: const TextStyle(fontSize: 24),
                      ),
                    Text(
                      option['label'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Self Assessment'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
              DropdownButtonFormField<String>(
                value: _selectedCrisisLevel.isEmpty
                    ? null
                    : _selectedCrisisLevel,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select crisis level (if applicable)',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ..._levelOptions.map(
                    (option) => DropdownMenuItem(
                      value: option['value'],
                      child: Text(option['label']),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedCrisisLevel = value ?? ''),
              ),
              const SizedBox(height: 16),

              // Anxiety Level (Optional)
              const Text(
                'Anxiety Level (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedAnxietyLevel.isEmpty
                    ? null
                    : _selectedAnxietyLevel,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select anxiety level (if applicable)',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ..._levelOptions.map(
                    (option) => DropdownMenuItem(
                      value: option['value'],
                      child: Text(option['label']),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedAnxietyLevel = value ?? ''),
              ),
              const SizedBox(height: 16),

              // Notes
              const Text(
                'Additional Notes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      'Describe how you\'re feeling, any concerns, or thoughts...',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please add some notes about how you\'re feeling';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitAssessment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Assessment',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

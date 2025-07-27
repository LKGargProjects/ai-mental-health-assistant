import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/assessment_provider.dart';
import '../models/assessment.dart';

class SelfAssessmentScreen extends StatefulWidget {
  const SelfAssessmentScreen({super.key});

  @override
  State<SelfAssessmentScreen> createState() => _SelfAssessmentScreenState();
}

class _SelfAssessmentScreenState extends State<SelfAssessmentScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AssessmentProvider>().loadQuestions();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mental Health Assessment'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: Consumer<AssessmentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.questions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      provider.clearError();
                      provider.loadQuestions();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.questions.isEmpty) {
            return const Center(
              child: Text('No assessment questions available'),
            );
          }

          return Column(
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (provider.responses.length + 1) / provider.questions.length,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              
              // Question counter
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Question ${_currentPage + 1} of ${provider.questions.length}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),

              // Questions
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: provider.questions.length,
                  itemBuilder: (context, index) {
                    final question = provider.questions[index];
                    final response = provider.responses
                        .where((r) => r.questionId == question.id)
                        .firstOrNull;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question
                          Text(
                            question.question,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 24),

                          // Answer options
                          if (question.type == 'multiple_choice' && question.options != null)
                            ...question.options!.map((option) => _buildMultipleChoiceOption(
                              option,
                              response?.answer == option,
                              (value) {
                                provider.setResponse(question.id, value);
                              },
                            )),

                          if (question.type == 'scale' && question.min != null && question.max != null)
                            _buildScaleOption(
                              question.min!,
                              question.max!,
                              response?.answer,
                              (value) {
                                provider.setResponse(question.id, value);
                              },
                            ),

                          const SizedBox(height: 32),

                          // Navigation buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_currentPage > 0)
                                ElevatedButton(
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  child: const Text('Previous'),
                                )
                              else
                                const SizedBox.shrink(),

                              if (_currentPage < provider.questions.length - 1)
                                ElevatedButton(
                                  onPressed: response?.answer != null
                                      ? () {
                                          _pageController.nextPage(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        }
                                      : null,
                                  child: const Text('Next'),
                                )
                              else
                                ElevatedButton(
                                  onPressed: provider.responses.length == provider.questions.length
                                      ? () => _submitAssessment(provider)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  child: const Text('Submit Assessment'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMultipleChoiceOption(
    String option,
    bool isSelected,
    Function(String) onSelect,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => onSelect(option),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Radio<String>(
                value: option,
                groupValue: isSelected ? option : null,
                onChanged: (value) => onSelect(value!),
              ),
              Expanded(
                child: Text(
                  option,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScaleOption(
    int min,
    int max,
    String? currentValue,
    Function(String) onSelect,
  ) {
    int selectedValue = currentValue != null ? int.tryParse(currentValue) ?? min : min;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a value from $min to $max:',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('$min'),
            Expanded(
              child: Slider(
                value: selectedValue.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min,
                onChanged: (value) {
                  onSelect(value.toInt().toString());
                },
              ),
            ),
            Text('$max'),
          ],
        ),
        Center(
          child: Text(
            'Selected: $selectedValue',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _submitAssessment(AssessmentProvider provider) async {
    await provider.submitAssessment();
    
    if (provider.currentResult != null && mounted) {
      // Show result dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Assessment Complete'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your Score: ${provider.currentResult!.score.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Personalized Feedback:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(provider.currentResult!.feedback),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }
} 
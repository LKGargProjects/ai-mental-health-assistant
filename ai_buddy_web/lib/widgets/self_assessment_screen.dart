import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'package:provider/provider.dart';
import 'package:ai_buddy_web/providers/assessment_provider.dart';
import './app_back_button.dart';

class SelfAssessmentScreen extends StatefulWidget {
  const SelfAssessmentScreen({super.key});

  @override
  State<SelfAssessmentScreen> createState() => _SelfAssessmentScreenState();
}

class _SelfAssessmentScreenState extends State<SelfAssessmentScreen> {
  final PageController _pageController = PageController();
  final Map<String, int> _answers = {};

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Over the last 2 weeks, how often have you been bothered by little interest or pleasure in doing things?',
      'options': ['Not at all', 'Several days', 'More than half the days', 'Nearly every day'],
    },
    {
      'question': 'Feeling down, depressed, or hopeless?',
      'options': ['Not at all', 'Several days', 'More than half the days', 'Nearly every day'],
    },
    {
      'question': 'Trouble falling or staying asleep, or sleeping too much?',
      'options': ['Not at all', 'Several days', 'More than half the days', 'Nearly every day'],
    },
    {
      'question': 'Feeling tired or having little energy?',
      'options': ['Not at all', 'Several days', 'More than half the days', 'Nearly every day'],
    },
  ];

  void _submitAssessment() {
    final assessmentProvider = Provider.of<AssessmentProvider>(context, listen: false);
    assessmentProvider.submitAssessment(_answers);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Self Assessment'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (ctx) {
            final canPop = Navigator.of(ctx).canPop();
            final route = ModalRoute.of(ctx);
            final isModal = route is PageRoute && route.fullscreenDialog == true;
            if (canPop) {
              return AppBackButton(isModal: isModal);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _questions.length + 1,
        itemBuilder: (context, index) {
          if (index == _questions.length) {
            return _buildSubmissionScreen();
          }
          return _buildQuestionPage(_questions[index], index);
        },
      ),
    );
  }

  Widget _buildQuestionPage(Map<String, dynamic> questionData, int index) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            questionData['question'],
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ...List.generate(questionData['options'].length, (optionIndex) {
            return RadioListTile<int>(
              title: Text(questionData['options'][optionIndex]),
              value: optionIndex,
              groupValue: _answers[questionData['question']],
              onChanged: (value) {
                setState(() {
                  _answers[questionData['question']] = value!;
                });
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubmissionScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Thank you for completing the assessment.',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _submitAssessment,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
} 
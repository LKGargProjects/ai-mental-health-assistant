import 'package:flutter/material.dart';
import 'self_assessment_widget.dart';

class SelfAssessmentScreen extends StatelessWidget {
  const SelfAssessmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mental Health Assessment'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const SelfAssessmentWidget(),
    );
  }
} 
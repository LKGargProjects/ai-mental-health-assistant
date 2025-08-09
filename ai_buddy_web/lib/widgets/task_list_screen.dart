import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wellness Tasks'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          if (taskProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (taskProvider.error != null) {
            return Center(
              child: Text(
                taskProvider.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          // Placeholder tasks
          final tasks = [
            {'title': 'Practice deep breathing for 5 minutes', 'completed': true},
            {'title': 'Go for a 15-minute walk', 'completed': false},
            {'title': 'Write down 3 things you are grateful for', 'completed': false},
            {'title': 'Disconnect from social media for 1 hour', 'completed': false},
          ];

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                leading: Checkbox(
                  value: task['completed'] as bool,
                  onChanged: (value) {
                    // Handle task completion
                  },
                ),
                title: Text(task['title'] as String),
              );
            },
          );
        },
      ),
    );
  }
}

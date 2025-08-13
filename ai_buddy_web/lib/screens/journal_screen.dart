
import 'package:flutter/material.dart';
import '../widgets/app_back_button.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
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
      body: const Center(
        child: Text('Journal Screen'),
      ),
    );
  }
}

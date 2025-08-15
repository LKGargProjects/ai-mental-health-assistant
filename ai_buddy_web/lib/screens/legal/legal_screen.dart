import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../widgets/app_back_button.dart';
import 'package:flutter/services.dart' show rootBundle;

class LegalScreen extends StatelessWidget {
  final String title;
  final String assetPath;
  const LegalScreen({super.key, required this.title, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load document'));
          }
          final data = snapshot.data ?? '# Document unavailable';
          return Markdown(
            data: data,
            padding: const EdgeInsets.all(16.0),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'quest_screen.dart';
import '../dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart';
import '../dhiwise/core/utils/size_utils.dart' as DhiwiseSizer;
import '../widgets/app_back_button.dart';

class QuestTabScreen extends StatefulWidget {
  const QuestTabScreen({Key? key}) : super(key: key);

  @override
  _QuestTabScreenState createState() => _QuestTabScreenState();
}

class _QuestTabScreenState extends State<QuestTabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest & Wellness', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events), text: 'Quests'),
            Tab(icon: Icon(Icons.self_improvement), text: 'Wellness'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const QuestScreen(),
          DhiwiseSizer.Sizer(
            builder: (context, orientation, deviceType) => WellnessDashboardScreen(),
          ),
        ],
      ),
    );
  }
}

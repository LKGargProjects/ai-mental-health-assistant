import 'package:flutter/material.dart';
import 'quest_screen.dart';
import '../dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart';
import '../dhiwise/core/utils/size_utils.dart' as dhiwise_sizer;
import '../widgets/app_back_button.dart';
import '../theme/text_style_helper.dart';
import '../theme/theme_helper.dart';

class QuestTabScreen extends StatefulWidget {
  const QuestTabScreen({super.key});

  @override
  State<QuestTabScreen> createState() => _QuestTabScreenState();
}

class _QuestTabScreenState extends State<QuestTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(
          _tabController.index == 0 ? "Today's Quests" : 'Wellness',
          style: TextStyleHelper.instance.headline24Bold,
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (ctx) {
            final canPop = Navigator.of(ctx).canPop();
            final route = ModalRoute.of(ctx);
            final isModal =
                route is PageRoute && route.fullscreenDialog == true;
            if (canPop) {
              return AppBackButton(isModal: isModal);
            }
            return const SizedBox.shrink();
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56 + 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: const [
                  Tab(icon: Icon(Icons.emoji_events), text: 'Quests'),
                  Tab(icon: Icon(Icons.self_improvement), text: 'Wellness'),
                ],
              ),
              Container(height: 8, color: appTheme.colorFFF3F4),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const QuestScreen(),
          dhiwise_sizer.Sizer(
            builder: (context, orientation, deviceType) =>
                WellnessDashboardScreen(),
          ),
        ],
      ),
    );
  }
}

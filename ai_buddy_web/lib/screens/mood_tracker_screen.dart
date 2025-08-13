
import 'package:flutter/material.dart';
import '../widgets/mood_tracker.dart';
import '../core/utils/size_utils.dart';
import '../theme/theme_helper.dart';
import '../theme/text_style_helper.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_back_button.dart';
import '../widgets/keyboard_dismissible_scaffold.dart';

class MoodTrackerScreen extends StatelessWidget {
  final bool showBottomNav;
  final ValueNotifier<int>? reselect; // currently unused; reserved for scroll/refresh on re-tap
  const MoodTrackerScreen({super.key, this.showBottomNav = true, this.reselect});

  @override
  Widget build(BuildContext context) {
    return KeyboardDismissibleScaffold(
      safeTop: false,
      safeBottom: false,
      bottomNavigationBar: showBottomNav ? const AppBottomNav(current: AppTab.mood) : null,
      body: Column(
            children: [
              // Header
              Container(
                color: appTheme.whiteCustom,
                padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 16.h),
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Row(
                    children: [
                      Builder(
                        builder: (ctx) {
                          final canPop = Navigator.of(ctx).canPop();
                          final route = ModalRoute.of(ctx);
                          final isModal = route is PageRoute && route.fullscreenDialog == true;
                          if (canPop) {
                            return AppBackButton(isModal: isModal);
                          }
                          return SizedBox(width: 44.h);
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Mood Tracker',
                          textAlign: TextAlign.center,
                          style: TextStyleHelper.instance.headline24Bold,
                        ),
                      ),
                      SizedBox(width: 44.h), // balance
                    ],
                  ),
                ),
              ),
              // Divider
              Container(
                height: 8.h,
                color: appTheme.colorFFF3F4,
              ),
              // Mood Tracker Content
              Expanded(
                child: Container(
                  color: Colors.transparent,
                  child: const MoodTrackerWidget(), // Fixed - now without duplicate header
                ),
              ),
            ],
      ),
    );
  }
}

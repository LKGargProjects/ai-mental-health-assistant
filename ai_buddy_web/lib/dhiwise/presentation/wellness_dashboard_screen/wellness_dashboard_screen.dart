import 'package:flutter/material.dart';
import 'dart:async';

import '../../core/app_export.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_image_view.dart';
import './widgets/progress_card_widget.dart';
import './widgets/recommendation_card_widget.dart';
import '../../../widgets/app_bottom_nav.dart';
import '../../../theme/text_style_helper.dart' as CoreTextStyles;
import '../../../widgets/assessment_splash.dart';

class WellnessDashboardScreen extends StatefulWidget {
  WellnessDashboardScreen({Key? key}) : super(key: key);

  @override
  State<WellnessDashboardScreen> createState() => _WellnessDashboardScreenState();
}

class _WellnessDashboardScreenState extends State<WellnessDashboardScreen>
    with SingleTickerProviderStateMixin {
  // UI-only state for TASK completion and progress
  bool _task1Done = false; // Focus reset
  bool _task2Done = false; // Study sprint
  int _baseSteps = 2; // total tasks today
  int _baseXp = 20; // base example XP shown initially
  bool _reminderOn = true; // UI-only reminder toggle (default ON)
  TimeOfDay _reminderTime = const TimeOfDay(hour: 19, minute: 0);

  // Habit formation microcopy (rotates while active)
  final List<String> _microcopy = const [
    "You've got this!",
    "Stay on track!",
    "Future you is proud",
    "Small steps, big wins",
    "Consistency is power"
  ];
  int _microIndex = 0;
  Timer? _microTimer;

  // Gentle pulse for near-time attention
  late AnimationController _pulseController;

  String _formatReminderTime(TimeOfDay t) {
    final hour12 = (t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod).toString();
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  bool _isTomorrowLabel(TimeOfDay t) {
    final now = DateTime.now();
    final todayTarget = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return todayTarget.isBefore(now); // if passed today, it's effectively tomorrow
  }

  bool _isReminderNear() {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, _reminderTime.hour, _reminderTime.minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    final minutes = target.difference(now).inMinutes;
    return minutes >= 0 && minutes < 10; // within next 10 minutes
  }

  void _startMicrocopyRotation() {
    _microTimer?.cancel();
    if (_reminderOn) {
      _microTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        setState(() {
          _microIndex = (_microIndex + 1) % _microcopy.length;
        });
      });
    }
  }

  List<double> _saturationMatrix(double s) {
    // Standard saturation matrix
    final double a = 0.213*(1-s) + s;
    final double b = 0.715*(1-s);
    final double c = 0.072*(1-s);
    return <double>[
      a, b, c, 0, 0,
      0.213*(1-s), 0.715*(1-s)+s, 0.072*(1-s), 0, 0,
      0.213*(1-s), 0.715*(1-s), 0.072*(1-s)+s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _startMicrocopyRotation();
  }

  @override
  void dispose() {
    _microTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(builder: (context, orientation, deviceType) {
      return SafeArea(
          child: Scaffold(
            body: Stack(children: [
              // Background Image (use full viewport like chat/mood)
              CustomImageView(
                  imagePath: ImageConstant.imgBackground1440x6351,
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  fit: BoxFit.cover),

              // Content (full viewport sizing)
              Container(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: Stack(children: [
                    // Side Background
                    Positioned(
                        left: 0,
                        top: 0,
                        child: CustomImageView(
                            imagePath: ImageConstant.imgBackground,
                            height: 635.h,
                            width: 3.h,
                            fit: BoxFit.cover)),

                    // Main Content
                    SingleChildScrollView(
                        child: Padding(
                            padding: EdgeInsets.all(
                                0), // Modified: Added required padding parameter
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeaderSection(),
                                  _buildMoodCheckInSection(),
                                  _buildProgressSection(),
                                  _buildRecommendationsSection(),
                                ]))),

                    // Bottom Background
                    Positioned(
                        bottom: 0,
                        left: 0,
                        child: CustomImageView(
                            imagePath: ImageConstant.imgBackground13x635,
                            height: 13.h,
                            width: MediaQuery.of(context).size.width,
                            fit: BoxFit.cover)),
                  ])),
            ]),
            bottomNavigationBar: const AppBottomNav(current: AppTab.quest)));
    });
  }

  Widget _buildHeaderSection() {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.h, vertical: 32.h),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        // Header renamed per PDF priorities
        Text('Today\'s Quest',
            style: CoreTextStyles.TextStyleHelper.instance.headline24Bold
                .copyWith(color: Color(0xFF47505E))),
        SizedBox(width: 12.h),
        CustomImageView(
            imagePath: ImageConstant.imgImage43x43,
            height: 43.h,
            width: 43.h),
          ]),
          GestureDetector(
              onTap: () {
                // Handle settings click
              },
              child: Container(
                  height: 38.h,
                  width: 38.h,
                  child: CustomImageView(
                      imagePath: ImageConstant.imgImage38x38,
                      height: 38.h,
                      width: 38.h,
                      fit: BoxFit.cover))),
        ]));
  }

  Widget _buildMoodCheckInSection() {
    return Container(
        margin: EdgeInsets.symmetric(horizontal: 70.h)
            .copyWith(top: 64.h, bottom: 32.h),
        decoration: BoxDecoration(
            color: Color(0xFFE3ECEF),
            borderRadius: BorderRadius.circular(28.h)),
        padding: EdgeInsets.symmetric(horizontal: 32.h, vertical: 44.h),
        child: Column(children: [
          // Large prompt card title
          Text('Quick check-in',
              textAlign: TextAlign.center,
              style: TextStyleHelper.instance.headline28Inter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF555F6D))),
          SizedBox(height: 8.h),
          // Prompt subtitle
          Text('Takes 2 minutes',
              textAlign: TextAlign.center,
              style: TextStyleHelper.instance.headline21Inter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF8C9CAA))),
          SizedBox(height: 32.h),
          CustomButton(
              text: 'Start',
              backgroundColor: Colors.white,
              textColor: Color(0xFF5A616F),
              borderColor: Color(0xFFF1F5F7),
              showBorder: true,
              padding: EdgeInsets.symmetric(horizontal: 48.h, vertical: 24.h),
              borderRadius: 37.h,
              textStyle: TextStyleHelper.instance.headline25BoldInter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false, // keep user on quest screen; use X to close
                  builder: (ctx) => const AssessmentSplash(),
                );
              }),
        ]));
  }

  Widget _buildProgressSection() {
    // Compute dynamic values from UI state (UI-only)
    final int completed = (_task1Done ? 1 : 0) + (_task2Done ? 1 : 0);
    final int stepsLeft = (_baseSteps - completed).clamp(0, _baseSteps);
    final int xpEarned = _baseXp + (completed * 10);
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 70.h).copyWith(bottom: 32.h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your Progress',
              style: TextStyleHelper.instance.display31BoldInter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF444D5C))),
          SizedBox(height: 28.h),
          Row(children: [
            Expanded(
                child: ProgressCardWidget(
                    imagePath: ImageConstant.imgImage65x52,
                    value: '$stepsLeft',
                    label: 'Steps Left',
                    backgroundColor: Color(0xFFE0F2E9))),
            SizedBox(width: 24.h),
            Expanded(
                child: ProgressCardWidget(
                    imagePath: ImageConstant.imgImage63x65,
                    value: '+$xpEarned',
                    label: 'XP Earned',
                    backgroundColor: Color(0xFFE8E7F8))),
          ]),
          SizedBox(height: 12.h),
          Text('Estimated time: 2–3 min',
              style: TextStyleHelper.instance.headline21Inter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF8C9CAA))),
        ]));
  }

  Widget _buildRecommendationsSection() {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 69.h).copyWith(bottom: 32.h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today\'s Recommendations',
              style: TextStyleHelper.instance.display32BoldInter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF4A5261))),
          SizedBox(height: 28.h),
          // Card 1 (TASK)
          RecommendationCardWidget(
              category: 'TASK',
              title: 'Focus reset (2 min)',
              subtitle: (_task1Done && _task2Done)
                  ? 'All steps complete 🎉'
                  : 'Quick breathing + desk tidy',
              imagePath: ImageConstant.imgImage131x130,
              completed: _task1Done,
              onTap: () {
                setState(() {
                  _task1Done = !_task1Done;
                });
              }),
          SizedBox(height: 24.h),
          // Card 2 (TASK)
          RecommendationCardWidget(
              category: 'TASK',
              title: 'Study sprint (10 min)',
              subtitle: 'Timer + no‑phone rule',
              imagePath: ImageConstant.imgImage130x130,
              completed: _task2Done,
              onTap: () {
                setState(() {
                  _task2Done = !_task2Done;
                });
              }),
          SizedBox(height: 24.h),
          // Card 3 (RESOURCE)
          RecommendationCardWidget(
              category: 'RESOURCE',
              title: 'Calm music',
              subtitle: 'Lo‑fi playlist',
              imagePath: ImageConstant.imgImage131x130,
              onTap: () {
                // Open resource (UI-only for now)
              }),
          SizedBox(height: 24.h),
          // Card 4 (TIP)
          RecommendationCardWidget(
              category: 'TIP',
              title: 'One tiny step',
              subtitle: 'Pick the easiest task first',
              imagePath: ImageConstant.imgImage130x130,
              onTap: () {
                // Show tip (UI-only for now)
              }),
          SizedBox(height: 24.h),
          // Card 5 (REMINDER) - themed toggle + change time
          Builder(
            builder: (context) {
              final near = _isReminderNear();
              if (near && !_pulseController.isAnimating) {
                _pulseController.repeat(reverse: true);
              } else if (!near && _pulseController.isAnimating) {
                _pulseController.stop();
              }
              final primary = Theme.of(context).colorScheme.primary;
              final borderBase = const Color(0xFFF4F5F7);
              final borderColor = near
                  ? Color.lerp(borderBase, primary, 0.6 + 0.4 * _pulseController.value)!
                  : borderBase;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: _reminderOn ? const Color(0xFFF4F1FF) : const Color(0xFFFEFEFE),
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(29.h),
                  boxShadow: _reminderOn
                      ? [
                          BoxShadow(
                            color: primary.withOpacity(0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [],
                ),
                padding: EdgeInsets.all(28.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'REMINDER',
                                style: TextStyleHelper.instance.title19BoldInter.copyWith(
                                  fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                                  color: const Color(0xFF8E98A7),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _reminderOn = !_reminderOn;
                                    _startMicrocopyRotation();
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  width: 52.h,
                                  height: 28.h,
                                  padding: EdgeInsets.symmetric(horizontal: 4.h, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: _reminderOn ? Theme.of(context).colorScheme.primary : const Color(0xFFE6EAF0),
                                    borderRadius: BorderRadius.circular(20.h),
                                  ),
                                  child: Align(
                                    alignment: _reminderOn ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      width: 20.h,
                                      height: 20.h,
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: _reminderOn
                                          ? Icon(Icons.check, size: 16.h, color: Theme.of(context).colorScheme.primary)
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _formatReminderTime(_reminderTime),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyleHelper.instance.headline26BoldInter.copyWith(
                                          fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                                          color: _reminderOn ? const Color(0xFF4C5664) : const Color(0xFFB8C0CC),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: _isTomorrowLabel(_reminderTime) ? 8.h : 0),
                                    _isTomorrowLabel(_reminderTime)
                                        ? Text(
                                            'tomorrow',
                                            style: TextStyleHelper.instance.headline21Inter.copyWith(
                                              fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                                              color: const Color(0xFF8E98A7),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.h),
                              OutlinedButton.icon(
                                onPressed: _reminderOn
                                    ? () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime: _reminderTime,
                                          builder: (context, child) {
                                            return Theme(data: Theme.of(context), child: child!);
                                          },
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            _reminderTime = picked;
                                            _reminderOn = true;
                                          });
                                        }
                                      }
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 10.h, vertical: 6.h),
                                  side: BorderSide(
                                    color: _reminderOn ? Theme.of(context).colorScheme.primary : const Color(0xFFB8C0CC),
                                  ),
                                  foregroundColor: _reminderOn ? Theme.of(context).colorScheme.primary : const Color(0xFFB8C0CC),
                                ),
                                icon: Icon(Icons.edit, size: 16.h),
                                label: const Text('Change'),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _reminderOn ? _microcopy[_microIndex] : 'Nudge me to finish the quest',
                              key: ValueKey(_microIndex.toString() + _reminderOn.toString()),
                              style: TextStyleHelper.instance.headline21Inter.copyWith(
                                fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                                color: const Color(0xFFA8B1BF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 24.h),
                    Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(19.h)),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(_reminderOn ? _saturationMatrix(1.15) : _saturationMatrix(0.85)),
                        child: CustomImageView(
                          imagePath: ImageConstant.imgImage131x130,
                          height: 130.h,
                          width: 130.h,
                          fit: BoxFit.cover,
                          radius: BorderRadius.circular(19.h),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ]));
  }
}

import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'planner_screen.dart';
import 'profile_screen.dart';
import 'saved_trips_screen.dart';

/// Main navigation: bottom bar on phones, side rail on wide screens.
class HomeShell extends StatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  /// Lets child screens switch tabs (e.g. "See all trips" on the dashboard).
  static HomeShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>();

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _plannerKey = GlobalKey<PlannerScreenState>();

  static const _destinations = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.edit_calendar_outlined, Icons.edit_calendar, 'Plan'),
    (Icons.luggage_outlined, Icons.luggage, 'My trips'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  void goTo(int index) => setState(() => _index = index);

  /// Opens the planner tab, optionally pre-filled with a destination.
  void openPlanner({String destination = '', String? travelType}) {
    setState(() => _index = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _plannerKey.currentState?.prefill(destination: destination, travelType: travelType);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardScreen(),
      PlannerScreen(key: _plannerKey),
      const SavedTripsScreen(),
      const ProfileScreen(),
    ];
    final body = IndexedStack(index: _index, children: pages);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 900) {
        return Scaffold(
          body: Row(children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: goTo,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Icon(Icons.travel_explore,
                    size: 32, color: Theme.of(context).colorScheme.primary),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: Text(d.$3),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ]),
        );
      }
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: goTo,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.$1),
                selectedIcon: Icon(d.$2),
                label: d.$3,
              ),
          ],
        ),
      );
    });
  }
}

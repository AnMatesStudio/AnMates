import 'package:flutter/material.dart';
import '../services/map_navigation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/anm_widgets.dart';
import 'discover/discover_view.dart';
import 'discover/wishlist_view.dart';
import 'chat/chat_list_view.dart';
import 'map/map_view.dart';
import 'match/swipe_view.dart';

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    MapNavigationService.instance.pending.addListener(_onMapNavRequest);
  }

  @override
  void dispose() {
    MapNavigationService.instance.pending.removeListener(_onMapNavRequest);
    super.dispose();
  }

  void _onMapNavRequest() {
    if (MapNavigationService.instance.pending.value != null) {
      setState(() => _selectedIndex = 1); // switch to Bản đồ tab
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const DiscoverView(),
      const MapView(),
      const WishlistView(),
      const ChatListView(),
      const SwipeView(),
    ];

    return Scaffold(
      backgroundColor: AppColors.mint,
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: AnmTabBar(
        activeIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

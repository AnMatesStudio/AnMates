import 'package:flutter/material.dart';
import '../shared/widgets/connectivity_banner.dart';
import '../shared/widgets/lazy_indexed_stack.dart';
import '../theme/app_theme.dart';
import '../widgets/anm_widgets.dart';
import 'chat/chat_list_view.dart';
import 'discover/discover_view.dart';
import 'discover/wishlist_view.dart';
import 'profile/profile_view.dart';

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  int _selectedIndex = 0;

  // Builders run lazily — Wishlist/Chat/Profile aren't built until tapped.
  // Once built, each tab subtree is retained (Offstage'd) so scroll
  // position, controllers, and other State survive tab switches.
  static final List<WidgetBuilder> _tabBuilders = [
    (_) => const DiscoverView(),
    (_) => const WishlistView(),
    (_) => const ChatListView(),
    (_) => const ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      // ConnectivityBanner wraps the tab content so the offline indicator
      // slides in above whichever tab is currently active.
      body: ConnectivityBanner(
        child: LazyIndexedStack(index: _selectedIndex, builders: _tabBuilders),
      ),
      bottomNavigationBar: AnmTabBar(
        activeIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/anm_widgets.dart';
import 'discover/discover_view.dart';
import 'discover/wishlist_view.dart';
import 'chat/chat_list_view.dart';
import 'profile/profile_view.dart';

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const DiscoverView(),
      const WishlistView(),
      const ChatListView(),
      const ProfileView(),
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

import 'package:flutter/material.dart';

// MARK: - Place Category
enum PlaceCategory {
  food('Ăn uống'),
  cafe('Cà phê'),
  bar('Bar & Nightlife'),
  cinema('Xem phim'),
  karaoke('Karaoke'),
  spa('Spa & Wellness'),
  outdoor('Ngoài trời');

  const PlaceCategory(this.label);
  final String label;
}

// MARK: - Mood
enum Mood {
  hungry('Đói bụng', '🍜'),
  chill('Chill', '☕'),
  active('Năng động', '🎮'),
  relax('Thư giãn', '🌿'),
  party('Party', '🎉');

  const Mood(this.label, this.emoji);
  final String label;
  final String emoji;

  Color get color {
    switch (this) {
      case Mood.hungry:
        return Colors.orange;
      case Mood.chill:
        return Colors.blue;
      case Mood.active:
        return Colors.green;
      case Mood.relax:
        return const Color(0xFF00b894);
      case Mood.party:
        return Colors.purple;
    }
  }
}

// MARK: - Place Review
class PlaceReview {
  final String id;
  final String authorName;
  final String authorEmoji;
  final int rating;
  final String content;
  final String timeAgo;
  final List<String> vibeTags;

  PlaceReview({
    required this.id,
    required this.authorName,
    required this.authorEmoji,
    required this.rating,
    required this.content,
    required this.timeAgo,
    required this.vibeTags,
  });

  static List<PlaceReview> get sampleReviews => [
    PlaceReview(
      id: '1',
      authorName: 'Linh N.',
      authorEmoji: '👩‍🎨',
      rating: 5,
      content:
          'View đẹp, đồ uống ngon, không gian instagram-able cực! Sẽ quay lại 💕',
      timeAgo: '2 ngày trước',
      vibeTags: ['Romantic 💕', 'Instagrammable 📸'],
    ),
    PlaceReview(
      id: '2',
      authorName: 'Minh T.',
      authorEmoji: '👨‍💻',
      rating: 4,
      content: 'Đồ ăn ok, giá hợp lý. Buổi tối hơi đông, nên đặt trước.',
      timeAgo: '5 ngày trước',
      vibeTags: ['Foodie 🍜', 'Lively 🎉'],
    ),
    PlaceReview(
      id: '3',
      authorName: 'Hà P.',
      authorEmoji: '👩‍💼',
      rating: 5,
      content: 'Phục vụ nhiệt tình, nhạc hay, không gian chill 🌃',
      timeAgo: '1 tuần trước',
      vibeTags: ['Chill ☕', 'Music 🎵'],
    ),
  ];
}

// MARK: - Place
class Place {
  final String id;
  final String name;
  final PlaceCategory category;
  final String emoji;
  final double rating;
  final String priceRange;
  final String distance;
  final String address;
  final List<String> vibeTags;
  final List<Color> gradient;
  bool isLiked;
  final String phone;
  final String openingHours;
  final int reviewCount;
  final String detailDescription;
  final List<PlaceReview> reviews;

  Place({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    required this.rating,
    required this.priceRange,
    required this.distance,
    required this.address,
    required this.vibeTags,
    required this.gradient,
    this.isLiked = false,
    this.phone = '+84 28 3822 1234',
    this.openingHours = '09:00 - 23:00',
    this.reviewCount = 128,
    this.detailDescription =
        'Một địa điểm tuyệt vời với không gian ấm cúng, phù hợp cho cả hẹn hò lẫn đi cùng bạn bè.',
    List<PlaceReview>? reviews,
  }) : reviews = reviews ?? PlaceReview.sampleReviews;

  static List<Place> get sampleData => [
    Place(
      id: '1',
      name: 'Astra Rooftop Bar',
      category: PlaceCategory.bar,
      emoji: '🌃',
      rating: 4.8,
      priceRange: '300-500k',
      distance: '0.8km',
      address: '123 Nguyễn Huệ, Q.1',
      vibeTags: ['Romantic 💕', 'Instagrammable 📸', 'Lively 🎉'],
      gradient: [const Color(0xFF6C5CE7), const Color(0xFFa29bfe)],
    ),
    Place(
      id: '2',
      name: 'Ramen House Saigon',
      category: PlaceCategory.food,
      emoji: '🍜',
      rating: 4.6,
      priceRange: '100-200k',
      distance: '1.2km',
      address: '45 Lê Lợi, Q.1',
      vibeTags: ['Cozy 🤫', 'Foodie 🍜', 'Local 🏠'],
      gradient: [const Color(0xFFe17055), const Color(0xFFfdcb6e)],
    ),
    Place(
      id: '3',
      name: 'Chill Corner Cafe',
      category: PlaceCategory.cafe,
      emoji: '☕',
      rating: 4.5,
      priceRange: '50-150k',
      distance: '0.5km',
      address: '78 Bùi Viện, Q.1',
      vibeTags: ['Quiet 🤫', 'Work-friendly 💻', 'Aesthetic 📸'],
      gradient: [const Color(0xFF00b894), const Color(0xFF55efc4)],
    ),
    Place(
      id: '4',
      name: 'Galaxy Karaoke VIP',
      category: PlaceCategory.karaoke,
      emoji: '🎤',
      rating: 4.3,
      priceRange: '200-400k',
      distance: '2.1km',
      address: '99 Trần Hưng Đạo, Q.5',
      vibeTags: ['Lively 🎉', 'Group 👥', 'Fun 🎵'],
      gradient: [const Color(0xFFfd79a8), const Color(0xFFe84393)],
    ),
    Place(
      id: '5',
      name: 'Zen Spa & Wellness',
      category: PlaceCategory.spa,
      emoji: '🧘',
      rating: 4.9,
      priceRange: '400-700k',
      distance: '1.5km',
      address: '12 Đồng Khởi, Q.1',
      vibeTags: ['Relaxing 🌿', 'Premium ✨', 'Quiet 🤫'],
      gradient: [const Color(0xFF00cec9), const Color(0xFF81ecec)],
    ),
    Place(
      id: '6',
      name: 'CGV Cinema Vincom',
      category: PlaceCategory.cinema,
      emoji: '🎬',
      rating: 4.4,
      priceRange: '100-200k',
      distance: '0.3km',
      address: 'Vincom Center, Q.1',
      vibeTags: ['Date 💕', 'Chill ☕', 'Indoor 🏢'],
      gradient: [const Color(0xFF2d3436), const Color(0xFF636e72)],
    ),
  ];
}

// MARK: - App User
class AppUser {
  final String id;
  final String name;
  final int age;
  final String occupation;
  final String bio;
  final String emoji;
  final List<String> vibeTags;
  final int vibeScore;
  bool isMatched;
  final List<Color> gradient;

  AppUser({
    required this.id,
    required this.name,
    required this.age,
    required this.occupation,
    required this.bio,
    required this.emoji,
    required this.vibeTags,
    required this.vibeScore,
    this.isMatched = false,
    required this.gradient,
  });

  static List<AppUser> get sampleData => [
    AppUser(
      id: '1',
      name: 'Linh Nguyễn',
      age: 24,
      occupation: 'UI/UX Designer',
      bio:
          'Thích khám phá quán cà phê mới, mê chụp ảnh và ăn ramen 🍜 Tìm bạn đi chill cuối tuần!',
      emoji: '👩‍🎨',
      vibeTags: [
        '☕ Coffee Addict',
        '📸 Photographer',
        '🍜 Foodie',
        '🎵 Music Lover',
      ],
      vibeScore: 92,
      gradient: [const Color(0xFFfd79a8), const Color(0xFF6C5CE7)],
    ),
    AppUser(
      id: '2',
      name: 'Minh Trần',
      age: 27,
      occupation: 'Software Engineer',
      bio:
          'Code by day, game by night 🎮 Muốn tìm teammate đi ăn sau giờ làm. Thích khám phá ẩm thực đường phố.',
      emoji: '👨‍💻',
      vibeTags: ['🎮 Gamer', '🍕 Foodie', '☕ Coffee', '🌏 Explorer'],
      vibeScore: 85,
      gradient: [const Color(0xFF00b894), const Color(0xFF00cec9)],
    ),
    AppUser(
      id: '3',
      name: 'Hà Phạm',
      age: 23,
      occupation: 'Marketing Executive',
      bio:
          'Yêu âm nhạc và sống về đêm 🌃 Hay đi bar, rooftop, live music. DM nếu muốn chill cùng!',
      emoji: '👩‍💼',
      vibeTags: ['🎵 Music Lover', '🍺 Social', '🌃 Night Owl', '📸 Insta'],
      vibeScore: 78,
      gradient: [const Color(0xFFfdcb6e), const Color(0xFFe17055)],
    ),
    AppUser(
      id: '4',
      name: 'Khoa Lê',
      age: 26,
      occupation: 'Freelancer',
      bio:
          'Traveler & coffee lover ✈️ Đang sống ở Sài Gòn, tìm bạn khám phá hidden gems của thành phố.',
      emoji: '🧑‍🚀',
      vibeTags: ['🌏 Traveler', '☕ Coffee', '📚 Bookworm', '🏃 Active'],
      vibeScore: 88,
      gradient: [const Color(0xFFa29bfe), const Color(0xFF6C5CE7)],
    ),
  ];
}

// MARK: - Chat Message
enum MessageType { text, viewOnce, emoji }

enum ViewOnceState { na, unseen, seen }

class ChatMessage {
  final String id;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  ViewOnceState viewOnceState;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.viewOnceState = ViewOnceState.na,
  });
}

// MARK: - Chat Conversation
class ChatConversation {
  final String id;
  final AppUser user;
  String lastMessage;
  String lastTime;
  int unreadCount;
  List<ChatMessage> messages;

  ChatConversation({
    required this.id,
    required this.user,
    required this.lastMessage,
    required this.lastTime,
    required this.unreadCount,
    required this.messages,
  });

  static List<ChatConversation> get sampleData => [
    ChatConversation(
      id: '1',
      user: AppUser.sampleData[0],
      lastMessage: 'Tối nay mày có rảnh không? 😊',
      lastTime: '20:17',
      unreadCount: 2,
      messages: [
        ChatMessage(
          id: 'm1',
          senderId: 'other',
          content: 'Ê! Tối nay mày có rảnh không? 😊',
          type: MessageType.text,
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          id: 'm2',
          senderId: 'me',
          content: 'Rảnh nè! Định đi đâu không?',
          type: MessageType.text,
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          id: 'm3',
          senderId: 'other',
          content: 'Tao đang ở Rooftop Bar A, view đẹp lắm 🌃',
          type: MessageType.text,
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          id: 'm4',
          senderId: 'other',
          content: '',
          type: MessageType.viewOnce,
          timestamp: DateTime.now(),
          viewOnceState: ViewOnceState.unseen,
        ),
        ChatMessage(
          id: 'm5',
          senderId: 'me',
          content: 'Wow gửi ảnh đi xem nào! 👀',
          type: MessageType.text,
          timestamp: DateTime.now(),
        ),
      ],
    ),
    ChatConversation(
      id: '2',
      user: AppUser.sampleData[1],
      lastMessage: 'Ảnh đã xem',
      lastTime: '18:30',
      unreadCount: 0,
      messages: [
        ChatMessage(
          id: 'm6',
          senderId: 'other',
          content: 'Có muốn đi ăn tối không?',
          type: MessageType.text,
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          id: 'm7',
          senderId: 'me',
          content: 'Ok đi! Quán nào?',
          type: MessageType.text,
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          id: 'm8',
          senderId: 'other',
          content: '',
          type: MessageType.viewOnce,
          timestamp: DateTime.now(),
          viewOnceState: ViewOnceState.seen,
        ),
      ],
    ),
    ChatConversation(
      id: '3',
      user: AppUser.sampleData[2],
      lastMessage: 'Cuối tuần party nhé 🎉',
      lastTime: 'Hôm qua',
      unreadCount: 1,
      messages: [
        ChatMessage(
          id: 'm9',
          senderId: 'other',
          content: 'Cuối tuần party nhé 🎉',
          type: MessageType.text,
          timestamp: DateTime.now(),
        ),
      ],
    ),
  ];
}

// MARK: - Dining Group
class DiningGroup {
  final String id;
  String name;
  Place? place;
  List<AppUser> members;
  int maxMembers;
  DateTime scheduledTime;
  Mood mood;
  String notes;
  bool isJoined;

  DiningGroup({
    required this.id,
    required this.name,
    this.place,
    required this.members,
    this.maxMembers = 4,
    required this.scheduledTime,
    required this.mood,
    this.notes = '',
    this.isJoined = false,
  });

  bool get isFull => members.length >= maxMembers;
  int get slotsLeft => maxMembers - members.length;
}

// MARK: - Food Suggestion
class FoodSuggestion {
  final String id;
  final String name;
  final String emoji;
  final String priceLevel;
  final String estimatedPrice;
  final int matchScore;
  final String reason;
  final int suitableFor;

  FoodSuggestion({
    required this.id,
    required this.name,
    required this.emoji,
    required this.priceLevel,
    required this.estimatedPrice,
    required this.matchScore,
    required this.reason,
    required this.suitableFor,
  });

  static List<FoodSuggestion> suggestions(int groupSize, Mood mood) {
    final all = [
      FoodSuggestion(
        id: '1',
        name: 'Lẩu Thái chua cay',
        emoji: '🍲',
        priceLevel: 'Trung bình',
        estimatedPrice: '200-300k/người',
        matchScore: 95,
        reason: 'Hoàn hảo cho nhóm $groupSize người, hợp mood ấm áp',
        suitableFor: 4,
      ),
      FoodSuggestion(
        id: '2',
        name: 'Bún Bò Huế',
        emoji: '🍜',
        priceLevel: 'Thấp',
        estimatedPrice: '60-90k/người',
        matchScore: 88,
        reason: 'Đậm đà, hợp khẩu vị Việt, giá rẻ',
        suitableFor: 2,
      ),
      FoodSuggestion(
        id: '3',
        name: 'BBQ Hàn Quốc',
        emoji: '🥩',
        priceLevel: 'Trung bình',
        estimatedPrice: '250-400k/người',
        matchScore: 92,
        reason: 'Phù hợp nhóm, không khí vui vẻ',
        suitableFor: 4,
      ),
      FoodSuggestion(
        id: '4',
        name: 'Sushi Combo',
        emoji: '🍣',
        priceLevel: 'Trung bình',
        estimatedPrice: '180-280k/người',
        matchScore: 85,
        reason: 'Sang trọng vừa phải, hợp date 2 người',
        suitableFor: 2,
      ),
      FoodSuggestion(
        id: '5',
        name: 'Pizza & Pasta',
        emoji: '🍕',
        priceLevel: 'Thấp',
        estimatedPrice: '120-180k/người',
        matchScore: 80,
        reason: 'Dễ chia sẻ, hợp nhóm bạn',
        suitableFor: 4,
      ),
    ];
    return all
        .where((s) => s.suitableFor == groupSize || groupSize == 4)
        .toList()
      ..sort((a, b) => b.matchScore.compareTo(a.matchScore));
  }
}

// MARK: - Curated Collection
class CuratedCollection {
  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> gradient;
  final int placeCount;

  CuratedCollection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.gradient,
    required this.placeCount,
  });

  static List<CuratedCollection> get samples => [
    CuratedCollection(
      id: '1',
      title: 'Date Night dưới 500k',
      subtitle: 'Lãng mạn không tốn nhiều ❤️',
      emoji: '💕',
      gradient: [const Color(0xFFfd79a8), const Color(0xFF6C5CE7)],
      placeCount: 12,
    ),
    CuratedCollection(
      id: '2',
      title: 'Rooftop Bars Sài Gòn',
      subtitle: 'View cực đỉnh về đêm 🌃',
      emoji: '🌃',
      gradient: [const Color(0xFF2d3436), const Color(0xFF6C5CE7)],
      placeCount: 8,
    ),
    CuratedCollection(
      id: '3',
      title: 'Hidden Gems Quận 1',
      subtitle: 'Ít người biết, chất lượng 💎',
      emoji: '💎',
      gradient: [const Color(0xFF00cec9), const Color(0xFF0984e3)],
      placeCount: 15,
    ),
    CuratedCollection(
      id: '4',
      title: 'Cafe làm việc cả ngày',
      subtitle: 'Wifi tốt, ổ cắm nhiều ☕',
      emoji: '☕',
      gradient: [const Color(0xFF00b894), const Color(0xFF55efc4)],
      placeCount: 20,
    ),
    CuratedCollection(
      id: '5',
      title: 'Trời mưa thì đi đâu?',
      subtitle: 'Indoor, ấm cúng 🌧️',
      emoji: '🌧️',
      gradient: [const Color(0xFF636e72), const Color(0xFF74b9ff)],
      placeCount: 10,
    ),
  ];
}

// MARK: - Place Filter
class PlaceFilter {
  double distance;
  double maxPrice;
  double minRating;
  bool openNow;
  String suitableFor;

  PlaceFilter({
    this.distance = 5.0,
    this.maxPrice = 500,
    this.minRating = 4.0,
    this.openNow = false,
    this.suitableFor = 'Mọi người',
  });

  static const List<String> suitableOptions = [
    'Mọi người',
    '1 người',
    'Nhóm bạn',
    'Date 💕',
    'Gia đình',
  ];
}

// MARK: - Theme Mode
enum ThemeMode2 {
  sunriseAmber,
  oceanBlue,
  sunsetOrange,
  midnight,
  purplePink,
  emeraldGreen;

  String get displayName {
    switch (this) {
      case ThemeMode2.sunriseAmber:
        return 'Sunrise Amber';
      case ThemeMode2.oceanBlue:
        return 'Ocean Blue';
      case ThemeMode2.sunsetOrange:
        return 'Sunset Orange';
      case ThemeMode2.midnight:
        return 'Midnight';
      case ThemeMode2.purplePink:
        return 'Purple Pink';
      case ThemeMode2.emeraldGreen:
        return 'Emerald Green';
    }
  }

  String get emoji {
    switch (this) {
      case ThemeMode2.sunriseAmber:
        return '🌅';
      case ThemeMode2.oceanBlue:
        return '☀️';
      case ThemeMode2.sunsetOrange:
        return '🌆';
      case ThemeMode2.midnight:
        return '🌙';
      case ThemeMode2.purplePink:
        return '🌃';
      case ThemeMode2.emeraldGreen:
        return '🌿';
    }
  }

  Color get accent {
    switch (this) {
      case ThemeMode2.sunriseAmber:
        return const Color(0xFFfdcb6e);
      case ThemeMode2.oceanBlue:
        return const Color(0xFF0984e3);
      case ThemeMode2.sunsetOrange:
        return const Color(0xFFe17055);
      case ThemeMode2.midnight:
        return const Color(0xFF6C5CE7);
      case ThemeMode2.purplePink:
        return const Color(0xFFfd79a8);
      case ThemeMode2.emeraldGreen:
        return const Color(0xFF00b894);
    }
  }

  static ThemeMode2 forCurrentHour() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) return ThemeMode2.sunriseAmber;
    if (hour >= 11 && hour < 17) return ThemeMode2.oceanBlue;
    if (hour >= 17 && hour < 20) return ThemeMode2.sunsetOrange;
    if (hour >= 20) return ThemeMode2.purplePink;
    return ThemeMode2.midnight;
  }
}

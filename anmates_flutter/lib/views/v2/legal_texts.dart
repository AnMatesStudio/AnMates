/// One titled section of a legal document; [vi] / [en] are the body paragraphs.
class LegalSection {
  const LegalSection(this.titleVi, this.titleEn, this.vi, this.en);
  final String titleVi, titleEn;
  final List<String> vi, en;
}

/// Shown under each document's title.
const String kLegalUpdated = '27/09/2026';
const String kLegalContact = 'anmates.studio@gmail.com';

const List<LegalSection> kTerms = [
  LegalSection(
    'Đồng ý với điều khoản',
    'Agreeing to these terms',
    ['Khi tạo tài khoản hoặc dùng ĂnMates, bạn đồng ý với các điều khoản này và Chính sách quyền riêng tư. Nếu không đồng ý, vui lòng không sử dụng ứng dụng.'],
    ['By creating an account or using ĂnMates you agree to these terms and to the Privacy Policy. If you do not agree, please do not use the app.'],
  ),
  LegalSection(
    'Ai được dùng ĂnMates',
    'Who can use ĂnMates',
    [
      'Bạn phải từ đủ 18 tuổi trở lên. Mỗi người chỉ dùng một tài khoản, với thông tin thật về bản thân.',
      'Chúng tôi có thể từ chối hoặc khoá tài khoản vi phạm các điều khoản này.',
    ],
    [
      'You must be at least 18 years old. One account per person, with truthful information about yourself.',
      'We may refuse or suspend accounts that break these terms.',
    ],
  ),
  LegalSection(
    'Cách cư xử',
    'How to behave',
    [
      'Không quấy rối, đe doạ, xúc phạm hay phân biệt đối xử với người khác.',
      'Không giả mạo người khác, không spam, quảng cáo hay lừa đảo.',
      'Không đăng nội dung khiêu dâm, bạo lực hoặc trái pháp luật Việt Nam.',
      'Tôn trọng lịch hẹn: nếu không đến được, hãy báo trước cho mate.',
    ],
    [
      'No harassment, threats, insults or discrimination.',
      'No impersonation, spam, advertising or scams.',
      'No sexual, violent or illegal content under Vietnamese law.',
      'Respect bookings: if you cannot make it, tell your mate in advance.',
    ],
  ),
  LegalSection(
    'An toàn khi gặp mặt',
    'Staying safe when you meet',
    [
      'ĂnMates giúp bạn tìm người đi ăn cùng nhưng không kiểm tra lý lịch người dùng. Hãy gặp ở nơi công cộng, tự lo phương tiện đi lại và báo cho người thân biết bạn đi đâu.',
      'Nếu có ai làm bạn không thoải mái, hãy dùng Chặn hoặc Báo cáo trong cuộc trò chuyện.',
    ],
    [
      'ĂnMates helps you find people to eat with but does not run background checks. Meet in public places, arrange your own transport and tell someone where you are going.',
      'If anyone makes you uncomfortable, use Block or Report in the chat.',
    ],
  ),
  LegalSection(
    'Báo cáo và khoá tài khoản',
    'Reports and suspensions',
    [
      'Báo cáo được đội ngũ ĂnMates xem xét. Tài khoản bị từ 3 người khác nhau báo cáo trong 30 ngày sẽ tạm khoá tự động cho tới khi được xem xét.',
      'Chúng tôi có thể khoá tài khoản vi phạm mà không cần báo trước.',
    ],
    [
      'Reports are reviewed by the ĂnMates team. An account reported by 3 different people within 30 days is suspended automatically until it is reviewed.',
      'We may suspend accounts that break the rules without prior notice.',
    ],
  ),
  LegalSection(
    'Nội dung của bạn',
    'Your content',
    [
      'Bạn giữ quyền với ảnh, tin nhắn và đánh giá của mình. Bạn cho phép ĂnMates lưu trữ và hiển thị chúng cho những người dùng liên quan để vận hành dịch vụ.',
    ],
    [
      'You keep the rights to your photos, messages and ratings. You allow ĂnMates to store them and show them to the relevant users in order to run the service.',
    ],
  ),
  LegalSection(
    'Giới hạn trách nhiệm',
    'Limitation of liability',
    ['ĂnMates được cung cấp "như hiện có". Chúng tôi không chịu trách nhiệm về hành vi của người dùng khác, về quán ăn, hay về những gì xảy ra trong các buổi gặp mặt.'],
    ['ĂnMates is provided "as is". We are not responsible for other users\' behaviour, for venues, or for what happens at meet-ups.'],
  ),
  LegalSection(
    'Chấm dứt',
    'Ending your account',
    ['Bạn có thể xoá tài khoản bất cứ lúc nào trong trang Tôi. Khi xoá, hồ sơ, match, tin nhắn và lịch hẹn của bạn sẽ bị xoá vĩnh viễn.'],
    ['You can delete your account at any time from the Me tab. Deleting it permanently removes your profile, matches, messages and bookings.'],
  ),
  LegalSection(
    'Thay đổi và luật áp dụng',
    'Changes and governing law',
    [
      'Chúng tôi có thể cập nhật điều khoản; thay đổi quan trọng sẽ được thông báo trong ứng dụng. Điều khoản này tuân theo pháp luật Việt Nam.',
      'Liên hệ: anmates.studio@gmail.com',
    ],
    [
      'We may update these terms; important changes are announced in the app. These terms are governed by the laws of Vietnam.',
      'Contact: anmates.studio@gmail.com',
    ],
  ),
];

const List<LegalSection> kPrivacy = [
  LegalSection(
    'Dữ liệu chúng tôi thu thập',
    'What we collect',
    [
      'Thông tin tài khoản: tên, email hoặc số điện thoại, ngày sinh, mật khẩu (được mã hoá).',
      'Hồ sơ: ảnh, giới thiệu, khẩu vị, vibe, mức chi tiêu.',
      'Vị trí gần đúng (toạ độ và quận) khi bạn cho phép, để tìm quán và mate quanh bạn.',
      'Hoạt động: lượt quẹt, match, tin nhắn, ảnh gửi trong chat, lịch hẹn, đánh giá, báo cáo và lượt chặn.',
    ],
    [
      'Account: name, email or phone number, date of birth, password (stored hashed).',
      'Profile: photos, bio, food tastes, vibe, spend preference.',
      'Approximate location (coordinates and district) when you allow it, to find venues and mates near you.',
      'Activity: swipes, matches, messages, photos sent in chat, bookings, ratings, reports and blocks.',
    ],
  ),
  LegalSection(
    'Chúng tôi dùng dữ liệu để',
    'How we use it',
    [
      'Ghép bạn với người có khẩu vị hợp và ở gần; hiển thị quán ăn phù hợp.',
      'Vận hành chat, lịch hẹn, thông báo và Trust Score.',
      'Giữ an toàn cho cộng đồng: xử lý báo cáo, khoá tài khoản vi phạm, xác minh email.',
    ],
    [
      'Match you with people who share your tastes and are nearby; show suitable venues.',
      'Run chat, bookings, notifications and the Trust Score.',
      'Keep the community safe: handle reports, suspend accounts that break the rules, verify emails.',
    ],
  ),
  LegalSection(
    'Người khác thấy gì',
    'What others see',
    ['Người dùng khác thấy tên, ảnh, tuổi, khẩu vị, vibe, quận và khoảng cách ước tính tới bạn. Họ không thấy email, số điện thoại hay toạ độ chính xác của bạn.'],
    ['Other users see your name, photos, age, tastes, vibe, district and an estimated distance. They do not see your email, phone number or exact coordinates.'],
  ),
  LegalSection(
    'Chia sẻ với bên thứ ba',
    'Sharing with third parties',
    ['Chúng tôi không bán dữ liệu của bạn. Dữ liệu được xử lý bởi các nhà cung cấp hạ tầng: Google Firebase (đăng nhập, lưu ảnh), Google Cloud (máy chủ) và dịch vụ email để gửi mã xác minh.'],
    ['We do not sell your data. It is processed by infrastructure providers: Google Firebase (sign-in, photo storage), Google Cloud (servers) and an email service to send verification codes.'],
  ),
  LegalSection(
    'Lưu trữ và xoá',
    'Keeping and deleting',
    ['Dữ liệu được giữ khi tài khoản còn hoạt động. Khi bạn xoá tài khoản, hồ sơ, match, tin nhắn, lịch hẹn, đánh giá và báo cáo liên quan sẽ bị xoá khỏi cơ sở dữ liệu.'],
    ['Data is kept while your account is active. When you delete your account, your profile, matches, messages, bookings, ratings and related reports are removed from our database.'],
  ),
  LegalSection(
    'Quyền của bạn',
    'Your rights',
    ['Theo Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân, bạn có quyền biết, truy cập, chỉnh sửa, xoá dữ liệu và rút lại sự đồng ý. Bạn có thể sửa hồ sơ và xoá tài khoản ngay trong ứng dụng, hoặc liên hệ chúng tôi.'],
    ['Under Decree 13/2023/ND-CP on personal data protection you have the right to be informed, to access, correct and delete your data, and to withdraw consent. You can edit your profile and delete your account in the app, or contact us.'],
  ),
  LegalSection(
    'Liên hệ',
    'Contact',
    ['Mọi câu hỏi về dữ liệu cá nhân: anmates.studio@gmail.com'],
    ['Questions about your personal data: anmates.studio@gmail.com'],
  ),
];

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/license_card.dart';
import '../models/license_template.dart';
import '../providers/database_provider.dart';
import '../services/app_preferences.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/license_card_preview.dart';
import '../widgets/paywall_bottom_sheet.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/product_gallery.dart';
import '../widgets/section_header.dart';

/// ホーム画面 — 「もふもふ免許センター」受付窓口
///
/// アプリの起点。看板風ヘッダー、受付番号札CTA、窓口案内、発行済み免許証を表示。
/// 初回起動時は FTUE オーバーレイを表示する。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// FTUE 表示フラグ
  bool _showFtue = false;

  /// FTUE パルスアニメーション
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // FTUE 表示チェック
    if (!AppPreferences.isFtueCompleted) {
      _showFtue = true;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// FTUE を閉じて作成フローへ
  void _dismissFtueAndCreate() {
    AppPreferences.setFtueCompleted();
    setState(() => _showFtue = false);
    _navigateToCreate();
  }

  /// FTUE を閉じるだけ
  void _dismissFtue() {
    AppPreferences.setFtueCompleted();
    setState(() => _showFtue = false);
  }

  /// 作成フローへ遷移（月間上限チェック付き）
  void _navigateToCreate() {
    if (!AppPreferences.canCreateLicense) {
      PaywallBottomSheet.show(context);
      return;
    }
    context.push('/create/photo');
  }

  @override
  Widget build(BuildContext context) {
    final licensesAsync = ref.watch(licensesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // メインコンテンツ（注文済みかどうかで配置を変える）
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSignboardHeader(context),
                const SizedBox(height: 20),

                if (!AppPreferences.hasOrdered) ...[
                  // 未注文: スライドショーを目立つ位置に
                  _buildProductShowcase(),
                  const SizedBox(height: 20),
                  _buildTicketCta(context),
                  const SizedBox(height: 10),
                  if (!AppPreferences.isPremium) _buildMonthlyCounter(),
                  const SizedBox(height: 20),
                  _buildCounterGuide(context),
                  const SizedBox(height: 24),
                  _buildIssuedLicenses(context, licensesAsync),
                ] else ...[
                  // 注文済み: 免許証を上部に、スライドショーは下部
                  _buildIssuedLicenses(context, licensesAsync),
                  const SizedBox(height: 20),
                  _buildTicketCta(context),
                  const SizedBox(height: 10),
                  if (!AppPreferences.isPremium) _buildMonthlyCounter(),
                  const SizedBox(height: 20),
                  _buildCounterGuide(context),
                  const SizedBox(height: 20),
                  _buildProductShowcase(compact: true),
                ],

                const SizedBox(height: 16),
                const BannerAdWidget(),
                const SizedBox(height: 32),
              ],
            ),
          ),
          // FTUE オーバーレイ
          if (_showFtue) _buildFtueOverlay(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 看板風ヘッダー
  // ─────────────────────────────────────────────

  Widget _buildSignboardHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topPadding + 12,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.secondary.withValues(alpha: 0.12),
            AppColors.background,
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // 看板
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.secondary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // 内側の二重枠線（装飾）
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'うちの子公安委員会',
                        style: GoogleFonts.zenMaruGothic(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMedium,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'もふもふ免許センター',
                        style: GoogleFonts.zenMaruGothic(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: 3.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 横線装飾
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(
                                color: AppColors.accent, thickness: 0.8),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.pets,
                              size: 16,
                              color: AppColors.accent,
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                                color: AppColors.accent, thickness: 0.8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '本日も元気に営業中',
                        style: GoogleFonts.zenMaruGothic(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 受付番号札風CTA
  // ─────────────────────────────────────────────

  Widget _buildTicketCta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToCreate,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // 番号札の穴（装飾）
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                // メインコンテンツ
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      // 受付窓口アイコン
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_a_photo,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '受付窓口',
                              style: GoogleFonts.zenMaruGothic(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '免許証をつくる',
                              style: GoogleFonts.zenMaruGothic(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '証明写真をお持ちのうえ窓口へ',
                              style: GoogleFonts.notoSansJp(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.white54, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 残数バッジ（累計制限）
  // ─────────────────────────────────────────────

  Widget _buildMonthlyCounter() {
    final remaining = AppPreferences.remainingCreations;
    final used = AppPreferences.totalCreationCount;
    final limit = AppPreferences.freeCreationLimit;

    final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final barColor = remaining > 0 ? AppColors.secondary : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                remaining > 0 ? Icons.confirmation_number_outlined : Icons.lock,
                size: 16,
                color: remaining > 0 ? AppColors.textMedium : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                remaining > 0
                    ? '発行枚数 $used/$limit（残り$remaining枚）'
                    : '無料枠を使い切りました',
                style: AppTypography.caption.copyWith(
                  color: remaining > 0 ? AppColors.textMedium : AppColors.primary,
                  fontWeight: remaining > 0 ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 窓口案内
  // ─────────────────────────────────────────────

  Widget _buildCounterGuide(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              '窓口案内',
              style: AppTypography.headingSmall,
            ),
          ),
          // 2×2 グリッド
          Row(
            children: [
              Expanded(
                child: _CounterCard(
                  icon: Icons.photo_library_rounded,
                  label: 'コレクション',
                  subtitle: '発行済み一覧',
                  onTap: () => context.push('/collection'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CounterCard(
                  icon: Icons.menu_book_rounded,
                  label: 'ペット手帳',
                  subtitle: '健康記録',
                  onTap: () => context.push('/pet-notebook'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CounterCard(
                  icon: Icons.local_shipping_rounded,
                  label: '実物グッズ',
                  subtitle: '注文する',
                  onTap: () => context.push('/order'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CounterCard(
                  icon: Icons.settings_rounded,
                  label: '設定',
                  subtitle: 'アプリ設定',
                  onTap: () => context.push('/settings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 商品スライドショー
  // ─────────────────────────────────────────────

  Widget _buildProductShowcase({bool compact = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              compact ? 'うちの子グッズ' : 'うちの子グッズ',
              style: AppTypography.headingSmall,
            ),
          ),
          ProductGallery(
            photos: kAllProductPhotos,
            height: compact ? 140 : 200,
            compact: compact,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 発行済み免許証
  // ─────────────────────────────────────────────

  Widget _buildIssuedLicenses(
    BuildContext context,
    AsyncValue<List<LicenseCard>> licensesAsync,
  ) {
    return licensesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (licenses) {
        if (licenses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.pets,
                      size: 40,
                      color: AppColors.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  const Text(
                    'まだ免許証がないよ！',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '上の受付窓口から作ってみよう',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: '発行済み免許証',
              onSeeMore: () => context.push('/collection'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: licenses.length > 10 ? 10 : licenses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final card = licenses[index];
                  return LicenseCardPreview(
                    petName: card.petName,
                    species: card.species,
                    licenseType:
                        LicenseType.findById(card.licenseType).label,
                    photoPath: card.photoPath,
                    savedImagePath: card.savedImagePath,
                    onTap: () => context.push('/collection'),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // FTUE オーバーレイ
  // ─────────────────────────────────────────────

  Widget _buildFtueOverlay() {
    return GestureDetector(
      onTap: _dismissFtue,
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // サンプル免許証カード（パルスアニメーション）
                  GestureDetector(
                    onTap: _dismissFtueAndCreate,
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: _buildSampleLicenseCard(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 誘導テキスト
                  Text(
                    'あなたの子もこんな免許証に！',
                    style: GoogleFonts.zenMaruGothic(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ペットの写真で世界に一つだけの免許証がつくれます',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(flex: 1),
                  // CTAボタン
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _dismissFtueAndCreate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'つくってみる',
                        style: GoogleFonts.zenMaruGothic(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // スキップ
                  TextButton(
                    onPressed: _dismissFtue,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'あとで見る',
                      style: GoogleFonts.notoSansJp(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// FTUE: サンプル免許証カード（プレースホルダ）
  Widget _buildSampleLicenseCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'うちの子公安委員会',
            style: GoogleFonts.zenMaruGothic(
              fontSize: 12,
              color: AppColors.textMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'にゃん転免許',
            style: GoogleFonts.zenMaruGothic(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sampleInfoRow('氏名', 'もふたろう'),
                    _sampleInfoRow('住所', 'にゃんこ市おひるね町'),
                    _sampleInfoRow('有効', 'うたた寝するまで'),
                    _sampleInfoRow('条件', '魚アプリDLしない事'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pets,
                  size: 40,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '発行: もふもふ免許センター',
            style: AppTypography.caption.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _sampleInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: AppTypography.caption.copyWith(fontSize: 11)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 窓口案内カード
// ─────────────────────────────────────────────

class _CounterCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _CounterCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.secondary, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    fontSize: 13,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

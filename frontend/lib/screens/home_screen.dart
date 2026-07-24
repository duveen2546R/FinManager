import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/insight.dart';
import '../models/transaction.dart';
import '../services/api.dart';
import '../services/storage.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../utils.dart';
import '../widgets/auth_fields.dart';
import '../widgets/district/bottom_nav.dart';
import '../widgets/district/gradient_card.dart';
import '../widgets/district/motion.dart';
import '../widgets/district/shimmer.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/spending_pie_chart.dart';
import 'account_screen.dart';
import 'add_transaction_screen.dart';
import 'ai_agent_screen.dart';
import 'all_transactions_screen.dart';
import 'expense_setup_screen.dart';
import 'import_review_screen.dart';

// Route arguments for Home (from login/register or a fresh launch).
class HomeArgs {
  final String? userId;
  final String? name;
  final String? email;
  final String? phoneNo;
  const HomeArgs({this.userId, this.name, this.email, this.phoneNo});
}

class _Stats {
  final double totalBalance;
  final double totalIncome;
  final double totalExpense;
  final double highestSpend;
  final double dailyAverage;
  final Map<String, double> spendingByCategory;
  const _Stats({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.highestSpend,
    required this.dailyAverage,
    required this.spendingByCategory,
  });

  static const empty = _Stats(
    totalBalance: 0,
    totalIncome: 0,
    totalExpense: 0,
    highestSpend: 0,
    dailyAverage: 0,
    spendingByCategory: {},
  );
}

// Neobank dashboard: light canvas, flat white cards, lime + black stat
// cards, black pill actions.
class HomeScreen extends StatefulWidget {
  static const route = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _errorMessage;
  String _userName = 'User';
  String _userEmail = 'no-email@finmanager.com';
  List<Txn> _transactions = [];
  List<Insight> _insights = [];
  Guidance? _guidance;
  _Stats _stats = _Stats.empty;
  bool _resolved = false;
  bool _balanceHidden = false;

  static _Stats _computeStats(List<Txn> transactions) {
    double totalIncome = 0;
    double totalExpense = 0;
    double highestSpend = 0;
    final spendingByCategory = <String, double>{};

    for (final txn in transactions) {
      if (txn.type == 'Income') {
        totalIncome += txn.amount;
      } else {
        totalExpense += txn.amount;
        if (txn.amount > highestSpend) highestSpend = txn.amount;
        spendingByCategory[txn.category] =
            (spendingByCategory[txn.category] ?? 0) + txn.amount;
      }
    }

    final oldest =
        transactions.isNotEmpty ? transactions.last.date : DateTime.now();
    final days =
        (DateTime.now().difference(oldest).inDays + 1).clamp(1, 1 << 31);

    return _Stats(
      totalBalance: totalIncome - totalExpense,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      highestSpend: highestSpend,
      dailyAverage: totalExpense / days,
      spendingByCategory: spendingByCategory,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolved) return;
    _resolved = true;
    _resolveUserAndLoad();
  }

  Future<void> _resolveUserAndLoad() async {
    final args = ModalRoute.of(context)?.settings.arguments as HomeArgs?;
    String? name = args?.name;
    String? email = args?.email;

    if (name == null || email == null) {
      final stored = await Storage.getUser();
      name ??= stored['name'];
      email ??= stored['email'];
    }

    _userName = name ?? 'User';
    _userEmail = email ?? 'no-email@finmanager.com';

    await _fetchData();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchData() async {
    if (mounted) setState(() => _errorMessage = null);
    try {
      // Transactions are the primary payload; insights/guidance are
      // best-effort extras and must never break the dashboard.
      final results = await Future.wait<dynamic>([
        Api.getTransactions(),
        Api.getInsights().catchError((_) => <Insight>[]),
        Api.getGuidance().catchError((_) => null),
      ]);
      if (!mounted) return;
      final txns = results[0] as List<Txn>;
      setState(() {
        _transactions = txns;
        _stats = _computeStats(txns);
        _insights = (results[1] as List<Insight>)
            .where((i) => i.status == 'open')
            .toList();
        _guidance = results[2] as Guidance?;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage =
          'Could not connect to the server. Check your network and IP address.');
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        _openActivity();
        break;
      case 2:
        _openAi();
        break;
      case 3:
        Navigator.pushNamed(context, AccountScreen.route,
            arguments:
                AccountArgs(userName: _userName, userEmail: _userEmail));
        break;
    }
  }

  Future<void> _openActivity() async {
    await Navigator.pushNamed(context, AllTransactionsScreen.route,
        arguments: AllTransactionsArgs(transactions: _transactions));
    _fetchData(); // transactions may have been deleted there
  }

  Future<void> _openAi() async {
    await Navigator.pushNamed(context, AiAgentScreen.route);
    _fetchData();
  }

  Future<void> _openAdd() async {
    await Navigator.pushNamed(context, AddTransactionScreen.route);
    _fetchData();
  }

  // The center "+" opens a sheet of money actions (a better home than the
  // Account screen for import + expense setup).
  void _openQuickActions(AppColors colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Quick actions',
                  style: TextStyle(
                      color: colors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
              const SizedBox(height: 16),
              _actionTile(
                colors,
                Ionicons.add_circle_outline,
                'Add transaction',
                'Record an expense or income',
                () async {
                  Navigator.pop(sheetContext);
                  await Navigator.pushNamed(
                      context, AddTransactionScreen.route);
                  _fetchData();
                },
              ),
              _actionTile(
                colors,
                Ionicons.cloud_upload_outline,
                'Import expenses',
                'Bring in a CSV statement',
                () async {
                  Navigator.pop(sheetContext);
                  await Navigator.pushNamed(context, ImportReviewScreen.route);
                  _fetchData();
                },
              ),
              _actionTile(
                colors,
                Ionicons.options_outline,
                'Expense setup',
                'Recurring bills & merchant rules',
                () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, ExpenseSetupScreen.route);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(AppColors colors, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.elevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(color: colors.card, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: colors.text),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: colors.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: colors.secondaryText, fontSize: 13)),
                ],
              ),
            ),
            Icon(Ionicons.chevron_forward,
                size: 18, color: colors.secondaryText),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    return Scaffold(
      backgroundColor: colors.background,
      extendBody: true,
      bottomNavigationBar: DistrictBottomNav(
        currentIndex: 0,
        onTap: _onNavTap,
        onAdd: () => _openQuickActions(colors),
        colors: colors,
      ),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? _SkeletonDashboard(colors: colors)
            : _errorMessage != null
                ? _errorView(colors)
                : _dashboard(colors),
      ),
    );
  }

  Widget _errorView(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Ionicons.cloud_offline_outline,
                size: 56, color: colors.secondaryText),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.text, fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              child: PrimaryButton(
                label: 'Retry',
                loading: false,
                colors: colors,
                onTap: _fetchData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboard(AppColors colors) {
    return RefreshIndicator(
      color: colors.text,
      backgroundColor: colors.card,
      onRefresh: _fetchData,
      child: ListView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          EntranceFade(child: _header(colors)),
          const SizedBox(height: 22),
          EntranceFade(
            delay: const Duration(milliseconds: 60),
            child: _balanceCard(colors),
          ),
          const SizedBox(height: 26),
          EntranceFade(
            delay: const Duration(milliseconds: 120),
            child: _sectionHeader(colors, 'Your stats'),
          ),
          const SizedBox(height: 12),
          EntranceFade(
            delay: const Duration(milliseconds: 140),
            child: _statsRail(colors),
          ),
          if (_guidance != null || _insights.isNotEmpty) ...[
            const SizedBox(height: 26),
            EntranceFade(
              delay: const Duration(milliseconds: 160),
              child: _sectionHeader(colors, 'Insights'),
            ),
            const SizedBox(height: 12),
            if (_guidance != null)
              EntranceFade(
                delay: const Duration(milliseconds: 170),
                child: _guidanceCard(colors, _guidance!),
              ),
            for (final insight in _insights.take(3)) ...[
              const SizedBox(height: 12),
              EntranceFade(
                delay: const Duration(milliseconds: 180),
                child: _InsightCard(
                  insight: insight,
                  colors: colors,
                  onFeedback: (feedback) => _sendFeedback(insight, feedback),
                ),
              ),
            ],
          ],
          const SizedBox(height: 26),
          EntranceFade(
            delay: const Duration(milliseconds: 180),
            child: _chartCard(
              colors,
              title: 'Expense breakdown',
              icon: Ionicons.pie_chart_outline,
              child: SpendingPieChart(
                spendingByCategory: _stats.spendingByCategory,
                colors: colors,
              ),
            ),
          ),
          const SizedBox(height: 16),
          EntranceFade(
            delay: const Duration(milliseconds: 220),
            child: _chartCard(
              colors,
              title: 'Monthly spending',
              icon: Ionicons.bar_chart_outline,
              child:
                  MonthlyBarChart(transactions: _transactions, colors: colors),
            ),
          ),
          const SizedBox(height: 26),
          EntranceFade(
            delay: const Duration(milliseconds: 260),
            child: _transactionsCard(colors),
          ),
        ],
      ),
    );
  }

  // ---- Header ----
  Widget _header(AppColors colors) {
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting, ${_userName.split(' ').first}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4)),
              const SizedBox(height: 3),
              Text('Welcome to FinManager',
                  style:
                      TextStyle(color: colors.secondaryText, fontSize: 14)),
            ],
          ),
        ),
        PressableScale(
          onTap: () => Navigator.pushNamed(
            context,
            AccountScreen.route,
            arguments:
                AccountArgs(userName: _userName, userEmail: _userEmail),
          ),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.card,
              shape: BoxShape.circle,
              border: Border.all(color: colors.accent, width: 2.5),
            ),
            alignment: Alignment.center,
            child: Text(initial,
                style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  // ---- Balance hero card (bold black) ----
  Widget _balanceCard(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Ionicons.wallet_outline,
                      size: 16, color: Colors.white.withValues(alpha: 0.55)),
                  const SizedBox(width: 8),
                  Text('Total balance',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              GestureDetector(
                onTap: () =>
                    setState(() => _balanceHidden = !_balanceHidden),
                behavior: HitTestBehavior.opaque,
                child: Icon(
                    _balanceHidden
                        ? Ionicons.eye_off_outline
                        : Ionicons.eye_outline,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.55)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
                _balanceHidden
                    ? '\u{20B9} ••••••'
                    : formatRupee(_stats.totalBalance),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5)),
          ),
          const SizedBox(height: 22),
          PressableScale(
            onTap: _openAdd,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Ionicons.add, size: 22, color: colors.onAccent),
                  const SizedBox(width: 8),
                  Text('Add money',
                      style: TextStyle(
                          color: colors.onAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Stats rail: lime + black + white cards ----
  Widget _statsRail(AppColors colors) {
    return SizedBox(
      height: 158,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _StatCard(
            label: 'Income',
            value: formatRupee(_stats.totalIncome),
            icon: Ionicons.trending_up,
            bg: colors.accent,
            fg: colors.onAccent,
          ),
          const SizedBox(width: 14),
          _StatCard(
            label: 'Expense',
            value: formatRupee(_stats.totalExpense),
            icon: Ionicons.trending_down,
            bg: const Color(0xFF1A1A1A),
            fg: Colors.white,
          ),
          const SizedBox(width: 14),
          _StatCard(
            label: 'Daily avg',
            value: formatRupee(_stats.dailyAverage),
            icon: Ionicons.pulse_outline,
            bg: colors.card,
            fg: colors.text,
            subFg: colors.secondaryText,
            badgeColor: colors.elevated,
            borderColor: colors.border,
          ),
          const SizedBox(width: 14),
          _StatCard(
            label: 'Highest',
            value: formatRupee(_stats.highestSpend),
            icon: Ionicons.flame_outline,
            bg: colors.card,
            fg: colors.text,
            subFg: colors.secondaryText,
            badgeColor: colors.elevated,
            borderColor: colors.border,
          ),
        ],
      ),
    );
  }

  Future<void> _sendFeedback(Insight insight, String feedback) async {
    setState(() => _insights.removeWhere((i) => i.id == insight.id));
    try {
      await Api.sendInsightFeedback(insight.id, feedback);
    } catch (_) {
      // Non-fatal: the insight simply reappears on the next refresh.
    }
  }

  // Lime "safe to spend" card from GET /expense-guidance.
  Widget _guidanceCard(AppColors colors, Guidance g) {
    return AccentCard(
      color: colors.accent,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.onAccent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Ionicons.compass_outline,
                size: 22, color: colors.onAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Safe to spend this week',
                    style: TextStyle(
                        color: colors.onAccent.withValues(alpha: 0.75),
                        fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(formatRupee(g.recommendedWeeklyLimit),
                    style: TextStyle(
                        color: colors.onAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(AppColors colors, String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                color: colors.text,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3)),
        if (onSeeAll != null)
          PressableScale(
            onTap: onSeeAll,
            child: Text('See all',
                style: TextStyle(
                    color: colors.secondaryText,
                    fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  Widget _chartCard(AppColors colors,
      {required String title, required IconData icon, required Widget child}) {
    return SurfaceCard(
      color: colors.card,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: colors.elevated, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: colors.text),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      color: colors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
            ],
          ),
          const SizedBox(height: 22),
          Center(child: child),
        ],
      ),
    );
  }

  // ---- Transactions card ----
  Widget _transactionsCard(AppColors colors) {
    return SurfaceCard(
      color: colors.card,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Transactions',
                  style: TextStyle(
                      color: colors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              PressableScale(
                onTap: () => Navigator.pushNamed(
                  context,
                  AllTransactionsScreen.route,
                  arguments: AllTransactionsArgs(transactions: _transactions),
                ),
                child: Text('See all',
                    style: TextStyle(
                        color: colors.secondaryText,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No transactions recorded yet.',
                    style: TextStyle(color: colors.secondaryText)),
              ),
            )
          else
            for (final txn in _transactions.take(5))
              _TxnRow(txn: txn, colors: colors),
        ],
      ),
    );
  }
}

// Deterministic expense-insight card with feedback actions.
class _InsightCard extends StatelessWidget {
  final Insight insight;
  final AppColors colors;
  final void Function(String feedback) onFeedback;
  const _InsightCard({
    required this.insight,
    required this.colors,
    required this.onFeedback,
  });

  IconData get _icon {
    final kind = insight.kind.toLowerCase();
    if (kind.contains('subscription') || kind.contains('recurring')) {
      return Ionicons.repeat_outline;
    }
    if (kind.contains('spike') || kind.contains('anomal')) {
      return Ionicons.trending_up_outline;
    }
    if (kind.contains('due') || kind.contains('commitment')) {
      return Ionicons.calendar_outline;
    }
    return Ionicons.bulb_outline;
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: colors.card,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.elevated,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 20, color: colors.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(insight.title,
                        style: TextStyle(
                            color: colors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(insight.message,
                        style: TextStyle(
                            color: colors.secondaryText,
                            fontSize: 13.5,
                            height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip('Helpful', Ionicons.thumbs_up_outline,
                  () => onFeedback('helpful')),
              const SizedBox(width: 8),
              _chip('Not right', Ionicons.thumbs_down_outline,
                  () => onFeedback('incorrect')),
              const SizedBox(width: 8),
              _chip('Dismiss', Ionicons.close_outline,
                  () => onFeedback('ignored')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon, VoidCallback onTap) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colors.elevated,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: colors.text),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: colors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// Stat tile in the horizontal rail.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color? subFg;
  // Theme-aware badge/border for surface cards; null → derive from fg.
  final Color? badgeColor;
  final Color? borderColor;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.bg,
    required this.fg,
    this.subFg,
    this.badgeColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    // On bold-fill cards the badge is a faint wash of the fg colour; on
    // surface cards it uses the theme's elevated tone so the icon stays visible
    // in both light and dark mode.
    final badgeBg = badgeColor ?? fg.withValues(alpha: 0.14);
    return Container(
      width: 172,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(26),
        border:
            borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: fg),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    maxLines: 1,
                    style: TextStyle(
                        color: fg,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
              ),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: (subFg ?? fg)
                          .withValues(alpha: subFg == null ? 0.72 : 1),
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

// Transaction row inside the white card.
class _TxnRow extends StatelessWidget {
  final Txn txn;
  final AppColors colors;
  const _TxnRow({required this.txn, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isExpense = txn.type == 'Expense';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.elevated,
              shape: BoxShape.circle,
            ),
            child: Icon(iconForCategory(txn.category),
                size: 20, color: colors.text),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(formatShortDate(txn.date),
                    style: TextStyle(
                        color: colors.secondaryText, fontSize: 12.5)),
              ],
            ),
          ),
          if (isExpense)
            Text('-${formatRupee(txn.amount)}',
                style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 15))
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('+${formatRupee(txn.amount)}',
                  style: TextStyle(
                      color: colors.onAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

// Shimmer skeleton matching the dashboard layout.
class _SkeletonDashboard extends StatelessWidget {
  final AppColors colors;
  const _SkeletonDashboard({required this.colors});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      colors: colors,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 200, height: 22, colors: colors),
                    const SizedBox(height: 8),
                    SkeletonBox(width: 140, height: 14, colors: colors),
                  ],
                ),
              ),
              SkeletonBox(width: 48, height: 48, radius: 24, colors: colors),
            ],
          ),
          const SizedBox(height: 22),
          SkeletonBox(height: 196, radius: 30, colors: colors),
          const SizedBox(height: 26),
          SkeletonBox(width: 120, height: 20, colors: colors),
          const SizedBox(height: 12),
          SizedBox(
            height: 158,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, _) => SkeletonBox(
                  width: 172, height: 158, radius: 26, colors: colors),
            ),
          ),
          const SizedBox(height: 26),
          SkeletonBox(height: 260, radius: 24, colors: colors),
          const SizedBox(height: 16),
          SkeletonBox(height: 260, radius: 24, colors: colors),
          const SizedBox(height: 26),
          SkeletonBox(height: 300, radius: 24, colors: colors),
        ],
      ),
    );
  }
}

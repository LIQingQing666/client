import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../provider/auth_provider.dart';
import '../../provider/service_providers.dart';
import '../../provider/user_provider.dart';

/// 充值套餐数据模型
final class _RechargePackage {
  const _RechargePackage({
    required this.price,
    required this.coins,
    required this.bonus,
    required this.isHot,
    required this.isBest,
  });

  final int price; // 充值金额（元）
  final int coins; // 到账抖币
  final int bonus; // 赠送抖币
  final bool isHot; // 最受欢迎标签
  final bool isBest; // 最划算标签

  double get bonusPercent => (bonus / price) * 100;
  int get totalCoins => coins + bonus;
}

/// 预置套餐列表
const List<_RechargePackage> _packages = [
  _RechargePackage(price: 6, coins: 6, bonus: 0, isHot: false, isBest: false),
  _RechargePackage(price: 30, coins: 30, bonus: 3, isHot: false, isBest: false),
  _RechargePackage(price: 98, coins: 98, bonus: 15, isHot: true, isBest: false),
  _RechargePackage(price: 198, coins: 198, bonus: 45, isHot: false, isBest: true),
  _RechargePackage(price: 328, coins: 328, bonus: 85, isHot: false, isBest: false),
  _RechargePackage(price: 648, coins: 648, bonus: 200, isHot: false, isBest: false),
];

final class CoinRechargePage extends ConsumerStatefulWidget {
  const CoinRechargePage({
    super.key,
    this.from,
    this.orderId,
    this.payAmount,
  });

  final String? from;
  final String? orderId;
  final double? payAmount;

  @override
  ConsumerState<CoinRechargePage> createState() => _CoinRechargePageState();
}

final class _CoinRechargePageState extends ConsumerState<CoinRechargePage>
    with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  String _selectedPayment = 'wechat';
  bool _isPaying = false;
  int? _selectedPackageIndex;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  double get _inputAmount {
    if (_selectedPackageIndex != null) {
      return _packages[_selectedPackageIndex!].price.toDouble();
    }
    final text = _amountController.text;
    final amount = double.tryParse(text);
    return (amount != null && amount > 0) ? amount : 0;
  }

  _RechargePackage? get _selectedPackage =>
      _selectedPackageIndex != null ? _packages[_selectedPackageIndex!] : null;

  void _selectPackage(int index) {
    setState(() {
      _selectedPackageIndex = index;
      _amountController.clear();
    });
    _bounceController.forward(from: 0);
  }

  Future<void> _doRecharge() async {
    final amount = _inputAmount;
    if (amount <= 0) {
      _showToast('请选择或输入充值金额');
      return;
    }

    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn || auth.userId == null) {
      context.pushNamed('login');
      return;
    }

    setState(() => _isPaying = true);

    try {
      final api = ref.read(rechargeApiProvider);
      final result = await api.createRecharge(
        userId: auth.userId!,
        amount: amount,
        paymentMethod: _selectedPayment,
      );

      final newBalance = (result['new_balance'] as num).toDouble();
      ref.read(userProvider.notifier).updateCoinBalance(newBalance);

      if (mounted) {
        final queryParams = <String, String>{
          'amount': amount.toString(),
          'bonus': (result['bonus_amount'] as num).toString(),
          'total': (result['total_coins'] as num).toString(),
          'new_balance': newBalance.toString(),
        };
        if (widget.from == 'payment' && widget.orderId != null) {
          queryParams['from'] = 'payment';
          queryParams['order_id'] = widget.orderId!;
          queryParams['pay_amount'] = (widget.payAmount ?? 0).toString();
        }
        context.pushReplacementNamed('rechargeResult', queryParameters: queryParams);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPaying = false);
        _showToast('充值失败，请重试');
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = ref.watch(userProvider);
    final isLoggedIn = auth.isLoggedIn;
    final canPay = _inputAmount > 0 && !_isPaying;

    return Scaffold(
      appBar: AppBar(
        title: const Text('抖币充值'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.paddingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== 顶部金色渐变 Banner =====
                  _buildBanner(),

                  const SizedBox(height: AppDimens.paddingLg),

                  // ===== 充值套餐阶梯卡片 =====
                  const Text(
                    '选择充值方案',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppDimens.paddingSm),

                  // 赠送比例阶梯指示
                  _buildBonusScaleBar(),
                  const SizedBox(height: AppDimens.paddingMd),

                  // 套餐卡片网格
                  _buildPackageGrid(),

                  const SizedBox(height: AppDimens.paddingLg),

                  // ===== 自定义金额（折叠式） =====
                  _buildCustomAmountInput(),

                  const SizedBox(height: AppDimens.paddingLg),

                  // ===== 支付方式 =====
                  const Text(
                    '支付方式',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppDimens.paddingSm),
                  _PaymentMethodTile(
                    icon: Icons.wechat,
                    title: '微信支付',
                    subtitle: '推荐使用',
                    isSelected: _selectedPayment == 'wechat',
                    onTap: () => setState(() => _selectedPayment = 'wechat'),
                  ),
                  const SizedBox(height: AppDimens.paddingSm),
                  _PaymentMethodTile(
                    icon: Icons.payments_outlined,
                    title: '支付宝',
                    subtitle: '',
                    isSelected: _selectedPayment == 'alipay',
                    onTap: () => setState(() => _selectedPayment = 'alipay'),
                  ),

                  const SizedBox(height: AppDimens.paddingLg),

                  // ===== 当前余额 =====
                  if (isLoggedIn)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.monetization_on,
                            size: 16, color: Color(0xFFFFD700)),
                        const SizedBox(width: AppDimens.paddingSm),
                        Text(
                          '当前余额：${user.coinBalance.toStringAsFixed(0)} 抖币',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // ===== 底部确认按钮 =====
          _buildBottomBar(canPay),
        ],
      ),
    );
  }

  // ─── 顶部金色渐变 Banner ──────────────────────────
  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.paddingLg,
        horizontal: AppDimens.paddingLg,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD700),
            Color(0xFFFFA500),
            Color(0xFFFF8C00),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.white, size: 28),
              SizedBox(width: AppDimens.paddingSm),
              Text(
                '充得越多 · 送得越多',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.paddingSm),
          Text(
            '最高赠送比例 ${_packages.last.bonusPercent.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppDimens.paddingMd),
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimens.paddingSm,
              horizontal: AppDimens.paddingMd,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_offer, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  '限时优惠，多充多送',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 赠送比例阶梯条 ──────────────────────────────
  Widget _buildBonusScaleBar() {
    final maxPercent = _packages.last.bonusPercent;

    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '赠送比例阶梯',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: AppDimens.paddingSm),
          SizedBox(
            height: 20,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // 底条
                    Container(
                      height: 6,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // 填充条
                    Container(
                      height: 6,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFD700),
                            Color(0xFFFF8C00),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // 圆点标记
                    ..._packages.asMap().entries.map((entry) {
                      final i = entry.key;
                      final pkg = entry.value;
                      final left = (pkg.bonusPercent / maxPercent) * constraints.maxWidth;
                      final isSelected = _selectedPackageIndex == i;
                      return Positioned(
                        left: left - 8,
                        top: -5,
                        child: GestureDetector(
                          onTap: () => _selectPackage(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isSelected ? 18 : 12,
                            height: isSelected ? 18 : 12,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFF8C00)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFF8C00)
                                    : AppColors.textHint,
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF8C00).withOpacity(0.4),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppDimens.paddingSm),
          // 赠送比例标签
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _packages.map((pkg) {
              final percent = pkg.bonusPercent.toStringAsFixed(0);
              return Text(
                '${pkg.price}元\n送$percent%',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                ),
                textAlign: TextAlign.center,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── 套餐卡片网格 ──────────────────────────────
  Widget _buildPackageGrid() {
    return Column(
      children: [
        // 第一行：3个卡片
        Row(
          children: [
            Expanded(child: _buildPackageCard(0)),
            const SizedBox(width: AppDimens.paddingMd),
            Expanded(child: _buildPackageCard(1)),
            const SizedBox(width: AppDimens.paddingMd),
            Expanded(child: _buildPackageCard(2)),
          ],
        ),
        const SizedBox(height: AppDimens.paddingMd),
        // 第二行：3个卡片
        Row(
          children: [
            Expanded(child: _buildPackageCard(3)),
            const SizedBox(width: AppDimens.paddingMd),
            Expanded(child: _buildPackageCard(4)),
            const SizedBox(width: AppDimens.paddingMd),
            Expanded(child: _buildPackageCard(5)),
          ],
        ),
      ],
    );
  }

  Widget _buildPackageCard(int index) {
    final pkg = _packages[index];
    final isSelected = _selectedPackageIndex == index;

    return GestureDetector(
      onTap: () => _selectPackage(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          vertical: AppDimens.paddingMd,
          horizontal: AppDimens.paddingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF8E1)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF8C00)
                : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF8C00).withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: isSelected ? const Color(0xFF8B4513) : AppColors.textPrimary,
          ),
          child: Column(
            children: [
              // 标签
              if (pkg.isHot)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4500),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '最受欢迎',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (pkg.isBest)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '最划算',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF8B4513),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (!pkg.isHot && !pkg.isBest)
                const SizedBox(height: 20),
              // 价格
              Text(
                '¥${pkg.price}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFFFF8C00)
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              // 到账数量
              Text(
                '${pkg.totalCoins}币',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              // 赠送徽章
              if (pkg.bonus > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '赠${pkg.bonus}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF8C00),
                    ),
                  ),
                )
              else
                const Text(
                  '无赠送',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 自定义金额输入 ──────────────────────────────
  Widget _buildCustomAmountInput() {
    final isCustom = _selectedPackageIndex == null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: isCustom ? AppColors.primary : AppColors.divider,
          width: isCustom ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _selectedPackageIndex = null;
              });
            },
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.paddingMd),
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    size: 20,
                    color: isCustom ? AppColors.primary : AppColors.textHint,
                  ),
                  const SizedBox(width: AppDimens.paddingSm),
                  Text(
                    '自定义金额',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isCustom ? FontWeight.w600 : FontWeight.normal,
                      color: isCustom ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isCustom
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                    color: isCustom ? AppColors.primary : AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.paddingMd,
                0,
                AppDimens.paddingMd,
                AppDimens.paddingMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '¥',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: AppDimens.paddingSm),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: '输入充值金额',
                            hintStyle: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 20,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.paddingSm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: AppDimens.paddingSm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '自定义金额无额外赠送',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: isCustom
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  // ─── 底部确认按钮 ──────────────────────────────
  Widget _buildBottomBar(bool canPay) {
    final pkg = _selectedPackage;
    String buttonText;
    if (_isPaying) {
      buttonText = '';
    } else if (pkg != null && pkg.bonus > 0) {
      buttonText = '确认充值 ¥${pkg.price}（含赠${pkg.bonus}币）';
    } else if (_inputAmount > 0) {
      buttonText = '确认充值 ¥${_inputAmount.toStringAsFixed(2)}';
    } else {
      buttonText = '确认充值';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimens.paddingLg,
        AppDimens.paddingMd,
        AppDimens.paddingLg,
        AppDimens.paddingMd + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: canPay ? _doRecharge : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              elevation: canPay ? 2 : 0,
            ),
            child: _isPaying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── 支付方式选择组件 ──────────────────────────────
final class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.05)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppDimens.paddingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall,
                    ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

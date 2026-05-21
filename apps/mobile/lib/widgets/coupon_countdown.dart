import 'dart:async';

import 'package:flutter/material.dart';

import '../api/live_api.dart';
import '../core/app_constants.dart';

final class CouponCountdown extends StatefulWidget {
  const CouponCountdown({
    super.key,
    required this.coupon,
    this.onClaim,
  });

  final LiveCoupon coupon;
  final VoidCallback? onClaim;

  @override
  State<CouponCountdown> createState() => _CouponCountdownState();
}

final class _CouponCountdownState extends State<CouponCountdown> {
  String _remaining = '';

  @override
  void initState() {
    super.initState();
    _updateRemaining();
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final end = DateTime.tryParse(widget.coupon.endTime);
    if (end == null || end.isBefore(now)) {
      _remaining = '已结束';
      return;
    }

    final diff = end.difference(now);
    if (diff.inHours >= 1) {
      _remaining = '${diff.inHours}小时${diff.inMinutes.remainder(60)}分';
    } else if (diff.inMinutes >= 1) {
      _remaining = '${diff.inMinutes}分${diff.inSeconds.remainder(60)}秒';
    } else {
      _remaining = '${diff.inSeconds}秒';
    }

    Timer(const Duration(seconds: 10), () {
      if (mounted) {
        _updateRemaining();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final coupon = widget.coupon;
    final barWidth = coupon.totalCount > 0
        ? coupon.usedCount / coupon.totalCount
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingSm),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFE8453C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard, color: Colors.white, size: 16),
              const SizedBox(width: AppDimens.paddingXs),
              Expanded(
                child: Text(
                  coupon.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.paddingSm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(200),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(
                  '满${coupon.minOrder.toInt()}减${coupon.amount.toInt()}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.paddingSm),
          Row(
            children: [
              Text(
                '剩余 $_remaining',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: AppDimens.paddingSm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: barWidth,
                    backgroundColor: Colors.white.withAlpha(60),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.paddingSm),
              GestureDetector(
                onTap: coupon.isAvailable ? widget.onClaim : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.paddingMd,
                    vertical: AppDimens.paddingXs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    coupon.isAvailable ? '立即抢' : '已抢完',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: coupon.isAvailable
                          ? AppColors.primary
                          : AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

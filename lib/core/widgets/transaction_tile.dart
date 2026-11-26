import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/daos/transaction_dao.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.detail,
    required this.currency,
    this.onTap,
  });

  final TransactionDetail detail;
  final CurrencyPreset currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tx = detail.transaction;
    final isTransfer = tx.txType == 'transfer';
    final isIncome = tx.txType == 'income';

    final Color accentColor;
    final Color softBg;
    final IconData iconData;
    final IconData arrowIcon;
    final String titleText;
    final String subtitleText;
    final String amountText;

    if (isTransfer) {
      accentColor = colors.transfer;
      softBg = colors.transferSoft;
      iconData = Icons.swap_horiz_rounded;
      arrowIcon = Icons.swap_horiz_rounded;
      final destName = detail.destinationWallet?.name ?? 'Wallet';
      titleText = tx.note.isNotEmpty
          ? tx.note
          : '${detail.wallet.name} → $destName';
      subtitleText = '${detail.wallet.name} → $destName';
      amountText = CurrencyFormatter.format(tx.amountMinor, currency);
    } else {
      final cat = detail.category;
      accentColor = isIncome ? colors.income : colors.expense;
      softBg = cat != null
          ? Color(cat.colorValue).withValues(alpha: 0.14)
          : (isIncome ? colors.incomeSoft : colors.expenseSoft);
      iconData = cat != null
          ? appIconFromCode(cat.iconCodePoint)
          : (isIncome ? Icons.south_west_rounded : Icons.north_east_rounded);
      arrowIcon = isIncome
          ? Icons.south_west_rounded
          : Icons.north_east_rounded;
      titleText = tx.note.isNotEmpty ? tx.note : (cat?.name ?? 'Transaction');
      subtitleText =
          '${cat?.name ?? 'Uncategorized'} • ${detail.wallet.name}';
      amountText = CurrencyFormatter.format(
        isIncome ? tx.amountMinor : -tx.amountMinor,
        currency,
        showPlus: isIncome,
      );
    }

    final timeStr = DateFormat('HH:mm').format(tx.transactionDate);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: softBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                size: 20,
                color: isTransfer
                    ? colors.transfer
                    : (detail.category != null
                        ? Color(detail.category!.colorValue)
                        : accentColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.mutedText,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(arrowIcon, size: 14, color: accentColor),
                    const SizedBox(width: 3),
                    Text(
                      amountText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.mutedText,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small status badges shown next to a renter's name:
///
/// - a warning icon when the renter has notes on file, and
/// - a "verified" icon for trusted renters (rating >= 4 or at least
///   3 rentals).
///
/// Previously this exact block was duplicated in the renters list and in
/// the booking details view; it now lives in one place.
class RenterBadges extends StatelessWidget {
  const RenterBadges({super.key, required this.renter, this.iconSize = 18});

  final Map<String, dynamic> renter;
  final double iconSize;

  bool get _hasNotes {
    final notes = renter['notes'];
    return notes != null && notes.toString().trim().isNotEmpty;
  }

  bool get _isTrusted {
    final rating = (renter['rating'] as num?) ?? 0;
    final rentalCount = (renter['rental_count'] as num?) ?? 0;
    return rating >= 4 || rentalCount >= 3;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasNotes)
          Tooltip(
            message: 'توجد ملاحظات على العميل',
            child: Icon(
              Icons.warning_amber_rounded,
              color: AppColors.errorText,
              size: iconSize,
            ),
          ),
        if (_hasNotes && _isTrusted) const SizedBox(width: 4),
        if (_isTrusted)
          Tooltip(
            message: 'عميل مميز وموثوق',
            child: Icon(
              Icons.verified,
              color: AppColors.successText,
              size: iconSize,
            ),
          ),
      ],
    );
  }
}

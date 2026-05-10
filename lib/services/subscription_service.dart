import 'notification_service.dart';
import 'database_service.dart';
import 'storage_service.dart';

/// Utility service for subscription lifecycle management.
///
/// All methods are static and operate on the current session user read from
/// [StorageService]. Safe to call from background isolates (WorkManager) after
/// [StorageService.init()] has been called.
class SubscriptionService {
  SubscriptionService._();

  // ── Grace periods ──────────────────────────────────────────────────────────

  /// 1 day grace for monthly subscriptions before auto-downgrade.
  static const _monthlyGrace = Duration(days: 1);

  /// 5 days grace for yearly subscriptions before auto-downgrade.
  static const _yearlyGrace = Duration(days: 5);

  // ── Renewal window ─────────────────────────────────────────────────────────

  /// Monthly subscribers can renew starting 5 days before expiry.
  static const monthlyRenewalWindowDays = 5;

  /// Yearly subscribers can renew starting 7 days before expiry.
  static const yearlyRenewalWindowDays = 7;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Checks if the current user's paid plan has passed its grace period and
  /// automatically downgrades them to free when it has.
  ///
  /// Returns `true` if a downgrade occurred, `false` otherwise.
  /// Safe to call on every cold start and from the background task.
  static Future<bool> checkAndEnforceExpiry() async {
    final user = StorageService.currentUser;
    if (user == null || user.plan == 'free') return false;
    if (user.planExpiresAt == null) return false;

    final now = DateTime.now();
    final grace = user.subscriptionBillingCycle == 'yearly'
        ? _yearlyGrace
        : _monthlyGrace;

    if (now.isAfter(user.planExpiresAt!.add(grace))) {
      final updated = user.copyWith(
        plan: 'free',
        planExpiresAt: null,
        subscriptionBillingCycle: null,
      );
      await DatabaseService.updateUser(updated);
      await StorageService.setCurrentSession(
          updated, user.sessionToken ?? '');
      await NotificationService.cancelSubscriptionRenewalNotifications(user.id);
      return true;
    }
    return false;
  }

  /// Returns `true` when the current user is within the renewal window
  /// (5 days before expiry for monthly, 7 days for yearly).
  static bool isInRenewalWindow(DateTime? planExpiresAt, String? billingCycle) {
    if (planExpiresAt == null) return false;
    final windowDays = billingCycle == 'yearly'
        ? yearlyRenewalWindowDays
        : monthlyRenewalWindowDays;
    final daysLeft = planExpiresAt.difference(DateTime.now()).inDays;
    return daysLeft <= windowDays;
  }
}

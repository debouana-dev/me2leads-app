import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

// Price map (EUR cents) — matches the Firebase Cloud Function.
const _monthlyPrices = {'premium': 299, 'business': 599};
const _yearlyPrices  = {'premium': 2999, 'business': 5999};

/// Result of a completed Stripe checkout.
class PaymentCheckoutResult {
  final bool success;
  final String? paymentIntentId;
  final String? errorCode; // 'cancelled' | 'failed' | 'network_error'

  const PaymentCheckoutResult({
    required this.success,
    this.paymentIntentId,
    this.errorCode,
  });
}

/// Wraps the Stripe PaymentSheet flow via Firebase Cloud Functions.
///
/// The Stripe secret key never leaves the server — only the publishable key
/// is in the app. The Cloud Function `createPaymentIntent` creates the
/// Payment Intent server-side and returns only the client secret.
///
/// Deploy the Cloud Function from the `functions/` directory before use.
class StripeService {
  StripeService._();

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  static Future<PaymentCheckoutResult> startCheckout({
    required String plan,
    required String billingCycle,
    required String userEmail,
  }) async {
    final amount = billingCycle == 'yearly'
        ? (_yearlyPrices[plan] ?? 0)
        : (_monthlyPrices[plan] ?? 0);

    if (amount == 0) {
      return const PaymentCheckoutResult(
          success: false, errorCode: 'invalid_plan');
    }

    try {
      // 1. Call Firebase Cloud Function to create a Payment Intent.
      final callable = _functions.httpsCallable('createPaymentIntent');
      final result = await callable.call(<String, dynamic>{
        'plan': plan,
        'billingCycle': billingCycle,
        'amount': amount,
        'currency': 'eur',
      });
      final data = result.data as Map<String, dynamic>;
      final clientSecret = data['clientSecret'] as String;
      final paymentIntentId = data['paymentIntentId'] as String?;

      // 2. Initialize the PaymentSheet.
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Me2Leads',
          billingDetails: BillingDetails(email: userEmail),
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: Color(0xFF0B3C5D)),
          ),
        ),
      );

      // 3. Present the PaymentSheet (throws StripeException on cancel/failure).
      await Stripe.instance.presentPaymentSheet();

      return PaymentCheckoutResult(
        success: true,
        paymentIntentId: paymentIntentId,
      );
    } on StripeException catch (e) {
      final code = e.error.code == FailureCode.Canceled
          ? 'cancelled'
          : 'failed';
      debugPrint('StripeService: payment $code — ${e.error.message}');
      return PaymentCheckoutResult(success: false, errorCode: code);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('StripeService: Cloud Function error [${e.code}]: ${e.message}');
      return const PaymentCheckoutResult(
          success: false, errorCode: 'network_error');
    } catch (e) {
      debugPrint('StripeService: unexpected error: $e');
      return const PaymentCheckoutResult(
          success: false, errorCode: 'network_error');
    }
  }
}

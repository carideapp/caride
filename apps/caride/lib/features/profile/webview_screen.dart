import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class WebviewScreen extends StatefulWidget {
  /// Pass either a plain [amount] (legacy path) or a full [params] map
  /// with keys: url, reference, amountNaira, and optionally isSetupCard.
  const WebviewScreen({super.key, this.amount, this.params});

  final double? amount;
  final Map<String, dynamic>? params;

  @override
  State<WebviewScreen> createState() => _WebviewScreenState();
}

class _WebviewScreenState extends State<WebviewScreen> {
  WebViewController? _controller;
  final WalletRepository _walletRepo = WalletRepository();
  bool _verified = false;
  bool _verifying = false;
  bool _isLoading = true;
  bool _hasError = false;

  bool get _isSetupCard => widget.params?['isSetupCard'] == true;
  String? get _paymentUrl => widget.params?['url'] as String?;
  String? get _reference => widget.params?['reference'] as String?;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.primaryFocus?.unfocus();

    final url = _paymentUrl;
    if (url == null) {
      _simulatePayment();
      return;
    }
    _initWebview(url);
  }

  void _initWebview(String url) {
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
        onPageStarted: (url) => _handleUrlChange(url),
        onNavigationRequest: (req) {
          _handleUrlChange(req.url);
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) {
            debugPrint('WebView error: ${error.description}');
            if (mounted) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          }
        },
      ))
      ..loadRequest(Uri.parse(url));

    _controller = ctrl;
  }

  Future<void> _simulatePayment() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) context.pop(widget.amount);
  }

  void _handleUrlChange(String url) {
    if (_verified || _verifying) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final txRef = uri.queryParameters['tx_ref'] ??
        uri.queryParameters['reference'] ??
        uri.queryParameters['trxref'] ??
        _reference;
    final status = uri.queryParameters['status'];
    if (txRef != null &&
        (status == 'successful' ||
            url.contains('callback') ||
            url.contains('verify') ||
            url.contains('payment-callback'))) {
      _verifyPayment(txRef);
    }
  }

  Future<void> _verifyPayment(String reference) async {
    if (_verified || _verifying) return;
    setState(() => _verifying = true);
    try {
      final credited = await _walletRepo.verifyTopUp(reference: reference);
      if (!mounted) return;
      _verified = true;
      _showSuccessBottomSheet(credited);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _showSuccessBottomSheet(double credited) {
    if (!mounted) return;
    final formatted =
        '₦${credited.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    final navigator = Navigator.of(context);
    final currentContext = context;

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
        final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
        final cardBg = isDark ? AppColors.darkSurface : Colors.white;
        final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: borderColor)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.brand, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                _isSetupCard ? 'Card Saved Successfully!' : 'Top Up Successful!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSetupCard
                    ? 'Your card has been verified and saved for future bookings.'
                    : '$formatted has been added to your CaRide Wallet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (_isSetupCard) {
                      navigator.pop(true);
                    } else {
                      if (currentContext.mounted) {
                        currentContext.go(CustomerRoutePaths.wallet);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _retryLoad() {
    final url = _paymentUrl;
    if (url == null) return;
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _controller?.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final hasRealUrl = _paymentUrl != null;
    final ctrl = _controller;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _isSetupCard ? 'Add New Card' : 'Secure Payment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Stack(
                children: [
                  if (hasRealUrl && ctrl != null && !_hasError)
                    Builder(builder: (context) {
                      if (WebViewPlatform.instance is AndroidWebViewPlatform) {
                        return WebViewWidget.fromPlatformCreationParams(
                          params: AndroidWebViewWidgetCreationParams(
                            controller: ctrl.platform as AndroidWebViewController,
                            displayWithHybridComposition: true,
                          ),
                        );
                      }
                      return WebViewWidget(controller: ctrl);
                    })
                  else if (_hasError)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 56, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(
                              'Something went wrong',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Unable to load the payment page. Please check your internet connection and try again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: 160,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _retryLoad,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (!hasRealUrl)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: AppColors.brand),
                          const SizedBox(height: 20),
                          Text(
                            'Processing Payment...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please do not close this window',
                            style: TextStyle(fontSize: 14, color: secondaryTextColor),
                          ),
                        ],
                      ),
                    ),
                  if (_isLoading && hasRealUrl && !_hasError)
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    ),
                  if (_verifying)
                    Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: AppColors.brand),
                              SizedBox(height: 16),
                              Text(
                                'Verifying payment...',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';
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
    // Release any lingering Flutter focus so the native WebView can summon the keyboard
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
          // Only treat main frame errors as fatal
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
    if (txRef != null && (status == 'successful' || url.contains('callback') || url.contains('verify') || url.contains('payment-callback'))) {
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
      _showSuccessDialog(credited);
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

  void _showSuccessDialog(double credited) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final formatted =
        '₦${credited.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    
    // Capture the navigators/contexts before showDialog to avoid using stale context after pops.
    final navigator = Navigator.of(context);
    final currentContext = context;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(_isSetupCard ? 'Card Saved!' : 'Top Up Successful!',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _isSetupCard
                  ? 'Your card has been verified and saved for future payments.'
                  : '$formatted has been added to your CaRide Wallet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Done',
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
            ),
          ],
        ),
      ),
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
    final theme = Theme.of(context);
    final hasRealUrl = _paymentUrl != null;
    final ctrl = _controller;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(_isSetupCard ? 'Add New Card' : 'Secure Payment'),
        centerTitle: true,
      ),
      body: SafeArea(
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
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 56,
                          color: theme.colorScheme.error),
                      const SizedBox(height: AppSpacing.md),
                      Text('Something went wrong',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                          'Unable to load the payment page. Please try again.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'Retry',
                        onPressed: _retryLoad,
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
                    const CircularProgressIndicator(
                        color: AppColors.primaryGreen),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Processing Payment...',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Please do not close this window',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            if (_isLoading && hasRealUrl && !_hasError)
              const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primaryGreen),
              ),
            if (_verifying)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: AppColors.primaryGreen),
                          SizedBox(height: AppSpacing.md),
                          Text('Verifying payment...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

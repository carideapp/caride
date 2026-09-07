import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:design_system/design_system.dart';

/// A utility to download and cache network images directly to local storage.
/// This prevents redundant downloads on app restarts and makes images load instantly.
class DiskCacheManager {
  DiskCacheManager._();
  static final instance = DiskCacheManager._();

  /// Gets the local File path for the cached version of [url].
  Future<File> getCacheFile(String url) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return File('${tempDir.path}/$fileName');
  }

  /// Returns the cached [File] if it exists and is non-empty, otherwise returns null.
  Future<File?> getIfCached(String url) async {
    try {
      final file = await getCacheFile(url);
      if (await file.exists()) {
        final length = await file.length();
        if (length > 0) {
          return file;
        } else {
          // Clean up empty 0-byte file
          await file.delete();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Downloads the image at [url] and writes it to local storage.
  /// If it's already cached and valid, returns the cached file immediately.
  Future<File?> cacheImage(String url) async {
    if (url.isEmpty) return null;
    try {
      final cached = await getIfCached(url);
      if (cached != null) {
        return cached;
      }
      return await forceRedownloadAndCache(url);
    } catch (_) {}
    return null;
  }

  /// Deletes any existing local cache file for [url] and downloads fresh bytes from network/database.
  Future<File?> forceRedownloadAndCache(String url) async {
    if (url.isEmpty) return null;
    try {
      final file = await getCacheFile(url);
      if (await file.exists()) {
        await file.delete();
      }
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 15),
          );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      debugPrint('[DiskCacheManager] Error re-downloading image $url: $e');
    }
    return null;
  }
}

/// A widget that displays an image from the local disk cache.
/// If the cached image fails to load or is corrupted, it automatically fallbacks to
/// fetching directly from the network/database and re-caches it to disk.
class DiskCachedImage extends StatefulWidget {
  const DiskCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.loadingWidget,
    this.errorWidget,
  });

  final String imageUrl;
  final BoxFit fit;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  @override
  State<DiskCachedImage> createState() => _DiskCachedImageState();
}

class _DiskCachedImageState extends State<DiskCachedImage> {
  File? _localFile;
  bool _loading = true;
  bool _hasError = false;
  bool _isRefetching = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(DiskCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }

    try {
      // 1. Check if valid cached file exists
      final file = await DiskCacheManager.instance.getIfCached(widget.imageUrl);
      if (file != null) {
        if (mounted) {
          setState(() {
            _localFile = file;
            _loading = false;
          });
        }
        return;
      }

      // 2. Not cached or invalid: download and cache
      final cachedFile = await DiskCacheManager.instance.cacheImage(widget.imageUrl);
      if (cachedFile != null) {
        if (mounted) {
          setState(() {
            _localFile = cachedFile;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
            _hasError = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _handleCorruptedCache() async {
    if (_isRefetching || widget.imageUrl.isEmpty) return;
    _isRefetching = true;

    try {
      final freshFile = await DiskCacheManager.instance.forceRedownloadAndCache(widget.imageUrl);
      if (mounted && freshFile != null) {
        setState(() {
          _localFile = freshFile;
          _hasError = false;
        });
      }
    } catch (_) {
    } finally {
      _isRefetching = false;
    }
  }

  Widget _buildNetworkFallback() {
    return Image.network(
      widget.imageUrl,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.loadingWidget ??
            Container(
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.brand),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        return widget.errorWidget ??
            Container(
              color: Colors.black12,
              child: const Center(
                child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
              ),
            );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.loadingWidget ??
          Container(
            color: Colors.black12,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            ),
          );
    }

    if (_hasError || _localFile == null) {
      // Trigger background refetch & cache heal while rendering network fallback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleCorruptedCache();
      });
      return _buildNetworkFallback();
    }

    return Image.file(
      _localFile!,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        // Cached file is unreadable/corrupted -> delete, re-download, and render network fallback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleCorruptedCache();
        });
        return _buildNetworkFallback();
      },
    );
  }
}

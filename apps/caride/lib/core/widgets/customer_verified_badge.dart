import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Lightweight in-memory cache of customer verification statuses so lists/cards
/// across Driver and Fleet Manager screens render verified badges without
/// duplicate Firestore reads.
class CustomerVerificationCache {
  CustomerVerificationCache._();

  static final Map<String, bool> _cache = <String, bool>{};

  static bool? getCached(String uid) => _cache[uid];

  static void setCached(String uid, bool isVerified) {
    if (uid.isNotEmpty) {
      _cache[uid] = isVerified;
    }
  }

  static bool parseIsVerified(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data['isVerified'] == true ||
        data['isNinVerified'] == true ||
        (data['verificationStatus'] as String?)?.toLowerCase() == 'verified';
  }
}

/// Renders the CaRide Emerald Green Verified Checkmark Badge.
class CustomerVerifiedIcon extends StatelessWidget {
  const CustomerVerifiedIcon({
    super.key,
    this.size = 16,
    this.color,
    this.padding = const EdgeInsets.only(left: 5),
  });

  final double size;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Tooltip(
        message: 'Verified Customer (NIN)',
        child: Icon(
          Icons.verified_rounded,
          size: size,
          color: color ?? AppColors.brand,
        ),
      ),
    );
  }
}

/// Automatically resolves a customer's verification status from [isVerified]
/// or Firestore `customers/{customerUid}` and renders [CustomerVerifiedIcon]
/// if the customer is verified.
class CustomerVerifiedBadge extends StatelessWidget {
  const CustomerVerifiedBadge({
    super.key,
    this.customerUid,
    this.isVerified,
    this.size = 16,
    this.color,
    this.padding = const EdgeInsets.only(left: 5),
  });

  final String? customerUid;
  final bool? isVerified;
  final double size;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (isVerified == true) {
      if (customerUid != null && customerUid!.isNotEmpty) {
        CustomerVerificationCache.setCached(customerUid!, true);
      }
      return CustomerVerifiedIcon(
        size: size,
        color: color,
        padding: padding,
      );
    }

    if (isVerified == false && (customerUid == null || customerUid!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final cleanUid = (customerUid ?? '').trim();
    if (cleanUid.isEmpty) {
      return const SizedBox.shrink();
    }

    final cached = CustomerVerificationCache.getCached(cleanUid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('customers')
          .doc(cleanUid)
          .snapshots(),
      builder: (context, snapshot) {
        bool verified = cached ?? false;
        if (snapshot.hasData && snapshot.data != null) {
          verified = CustomerVerificationCache.parseIsVerified(
            snapshot.data!.data(),
          );
          CustomerVerificationCache.setCached(cleanUid, verified);
        }
        if (!verified) return const SizedBox.shrink();
        return CustomerVerifiedIcon(
          size: size,
          color: color,
          padding: padding,
        );
      },
    );
  }
}

/// Displays a customer's name with their verified badge right beside it.
class CustomerNameWithBadge extends StatelessWidget {
  const CustomerNameWithBadge({
    super.key,
    required this.name,
    this.customerUid,
    this.isVerified,
    this.style,
    this.badgeSize = 16,
    this.iconSize,
    this.badgeColor,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.mainAxisSize = MainAxisSize.min,
  });

  final String name;
  final String? customerUid;
  final bool? isVerified;
  final TextStyle? style;
  final double badgeSize;
  final double? iconSize;
  final Color? badgeColor;
  final int maxLines;
  final TextOverflow overflow;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: mainAxisSize,
      children: [
        Flexible(
          child: Text(
            name,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
          ),
        ),
        CustomerVerifiedBadge(
          customerUid: customerUid,
          isVerified: isVerified,
          size: iconSize ?? badgeSize,
          color: badgeColor,
        ),
      ],
    );
  }
}


import 'package:flutter/material.dart';

class Numpad extends StatelessWidget {
  const Numpad({
    super.key,
    required this.onNumberSelected,
    required this.onBackspace,
  });

  final ValueChanged<int> onNumberSelected;
  final VoidCallback onBackspace;

  Widget _buildKey(BuildContext context, String text, [VoidCallback? onTap]) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {
          final val = int.tryParse(text);
          if (val != null) onNumberSelected(val);
        },
        borderRadius: BorderRadius.circular(24),
        child: Center(
          child: Text(
            text,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onBackspace,
        borderRadius: BorderRadius.circular(24),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Theme.of(context).iconTheme.color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.6,
      padding: EdgeInsets.zero,
      children: [
        _buildKey(context, '1'),
        _buildKey(context, '2'),
        _buildKey(context, '3'),
        _buildKey(context, '4'),
        _buildKey(context, '5'),
        _buildKey(context, '6'),
        _buildKey(context, '7'),
        _buildKey(context, '8'),
        _buildKey(context, '9'),
        _buildKey(context, '*', () {}), // No-op as per standard OTP numpads
        _buildKey(context, '0'),
        _buildBackspaceKey(context),
      ],
    );
  }
}

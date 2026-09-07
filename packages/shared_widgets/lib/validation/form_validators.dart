/// Shared validators — no UI; used by [TextFormField.validator].
abstract final class FormValidators {
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  static String? phoneNg(String? value) {
    final v = value?.replaceAll(RegExp(r'\s'), '') ?? '';
    if (v.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^\+?234\d{10}$|^0\d{10}$').hasMatch(v)) {
      return 'Enter a valid Nigerian phone number';
    }
    return null;
  }

  static String? password(String? value, {int minLength = 8}) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String? other) {
    if (value != other) return 'Passwords do not match';
    return null;
  }
}

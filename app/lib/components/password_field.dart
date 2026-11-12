import 'package:flutter/material.dart';

/// Shared password input: obscured, no autocorrect/suggestions, no keyboard personalised
/// learning (keeps passwords out of keyboard caches/shared dictionaries). Password managers
/// still work through autofill hints. Use this for every password field.
class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, this.label = 'Password', this.validator, this.newPassword = false, this.onSubmitted});

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool newPassword;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _obscured ? 'Show password' : 'Hide password',
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../style/app_colors.dart';

class AppTextFormField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool isPassword;
  final bool isEmail;
  final bool enabled;
  final bool isPhone;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final String? hintText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Function(String)? onFieldSubmitted;
  final Function(String)? onChanged;

  const AppTextFormField({
    super.key,
    required this.label,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.isEmail = false,
    this.enabled = true,
    this.isPhone = false,
    this.validator,
    this.prefixIcon,
    this.hintText,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
  });

  @override
  State<AppTextFormField> createState() => _AppTextFormFieldState();
}

class _AppTextFormFieldState extends State<AppTextFormField> {
  bool _obscureText = true;
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _focusNode = widget.focusNode ?? FocusNode();

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  String? _defaultValidate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    if (widget.isPassword) {
      if (value.length < 6) {
        return 'Password must be at least 6 characters';
      }
    }

    if (widget.isEmail) {
      final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
      if (!emailRegex.hasMatch(value.trim())) {
        return 'Enter a valid email address';
      }
    }

    if (widget.isPhone) {
      final phoneRegex = RegExp(r'^01[0-2,5]{1}[0-9]{8}$');
      if (!phoneRegex.hasMatch(value.trim())) {
        return 'Enter a valid Egyptian phone number';
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _isFocused
            ? [
          BoxShadow(
            color: AppColors.kPrimaryColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ]
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextFormField(
        onChanged: widget.onChanged,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        enabled: widget.enabled,
        controller: widget.controller,
        focusNode: _focusNode,
        obscuringCharacter: '•',
        obscureText: widget.isPassword ? _obscureText : false,
        keyboardType: widget.isPhone
            ? TextInputType.phone
            : widget.keyboardType,
        inputFormatters: widget.keyboardType == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        validator: widget.validator ?? _defaultValidate,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          labelStyle: TextStyle(
            color: _isFocused ? AppColors.kPrimaryColor : Colors.grey.shade600,
            fontSize: 16,
            fontWeight: _isFocused ? FontWeight.w500 : FontWeight.normal,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          filled: true,
          fillColor: widget.enabled ? Colors.white : Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: widget.prefixIcon,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.kPrimaryColor,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
          ),
          errorStyle: TextStyle(
            color: Colors.red.shade600,
            fontSize: 13,
            height: 1.2,
          ),
          suffixIcon: widget.isPassword
              ? IconButton(
            splashRadius: 0.1,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            icon: Icon(
              _obscureText
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: _isFocused
                  ? AppColors.kPrimaryColor
                  : Colors.grey.shade400,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _obscureText = !_obscureText;
              });
            },
          )
              : null,
        ),
      ),
    );
  }
}

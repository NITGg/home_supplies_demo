import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/manager/auth_cubit.dart';
import '../../../auth/manager/auth_state.dart';
import '../../../auth/presentation/widgets/social_auth_button_row.dart';

class LinkAccountSheet extends StatelessWidget {
  final String? googleId;
  final String? appleId;

  const LinkAccountSheet({super.key, this.googleId, this.appleId});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.kPrimaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.link_rounded,
              size: 32,
              color: AppColors.kPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            loc.linkAccount,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            loc.linkAccountSubtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              if (state is AuthSocialLinkSuccess) {
                showSuccessBanner(context, state.message);
                Navigator.of(context).pop();
              } else if (state is AuthFailure) {
                showErrorBanner(context, state.message);
              }
            },
            child: SocialAuthButtons(
              isLink: true,
              googleId: googleId,
              appleId: appleId,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              loc.skip,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

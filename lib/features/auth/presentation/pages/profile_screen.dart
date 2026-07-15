import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/core/widgets/loading_screen.dart';
import 'package:tawreedat_courier/features/auth/presentation/widgets/social_auth_button_row.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/circel_back_button.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/change_password_sheet.dart';
import '../../../../core/widgets/delete_account_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';
import '../../manager/profile_cubit.dart';
import '../../manager/profile_states.dart';
import '../widgets/profile_header_section.dart';
import '../widgets/vehicle_info_card.dart';
import '../widgets/edit_profile_bottom_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations
        .localeOf(context)
        .languageCode == 'ar';
    context.read<ProfileCubit>().fetchProfile();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: BlocConsumer<ProfileCubit, ProfileState>(
          listener: (context, state) {
            if (state is ProfileFailure) {
              showErrorBanner(context, state.message);
            }
            if (state is ProfileUpdateSuccess) {
              showSuccessBanner(context, state.message);
            }
          },
          builder: (context, state) {
            if (state is ProfileLoading &&
                context
                    .read<ProfileCubit>()
                    .currentProfile == null) {
              return const Center(child: LoadingScreen(isOne: true));
            }

            final profile = context
                .read<ProfileCubit>()
                .currentProfile;
            if (profile == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(localizations.error),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ProfileCubit>().fetchProfile();
                      },
                      child: Text(localizations.retry),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                Future.wait([context.read<ProfileCubit>().fetchProfile()]);
              },
              color: AppColors.kPrimaryColor,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    automaticallyImplyLeading: false,
                    expandedHeight: 200,
                    floating: false,
                    pinned: true,
                    elevation: 0,
                    leading: CircleBackButton(onPressed: context.pop,),
                    backgroundColor: AppColors.kSecondaryColor,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.kSecondaryColor,
                              AppColors.kSecondaryLightColor.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: ProfileHeaderSection(profile: profile),
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      if(kDebugMode)
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey.shade200,
                        child: IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: Colors.grey.shade700,
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) =>
                                  EditProfileBottomSheet(profile: profile),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      spacing: 24,
                      children: [
                        SizedBox(height: 24),
                        VehicleInfoCard(courier: profile.courier),
                        _buildAccountInfoCard(context, profile),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Column(
                            children: [
                              if (profile.googleId == null ||
                                  (Platform.isIOS &&
                                      profile.appleId == null))...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context)!.linkAccount,
                                  ),
                                ),
                                BlocListener<AuthCubit, AuthState>(
                                  listener: (BuildContext context, state) {
                                    if (state is AuthSocialLinkSuccess) {
                                      showSuccessBanner(context, state.message);
                                      context
                                          .read<ProfileCubit>()
                                          .fetchProfile();
                                    }
                                    if (state is AuthFailure) {
                                      showErrorBanner(context, state.message);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    child: SocialAuthButtons(
                                      isLink: true,
                                      googleId: profile.googleId,
                                      appleId: profile.appleId,
                                    ),
                                  ),
                                ),
                              ],
                              if (profile.googleId == null &&
                                  profile.appleId == null)
                                AppCustomButton(
                                  onPressed: () {
                                    showChangePasswordBottomSheet(context);
                                  },
                                  text: localizations.changePassword,
                                  isSecondary: true,
                                  isLoading: context
                                      .read<AuthCubit>()
                                      .state is AuthLoading,
                                ),
                              AppCustomButton(
                                onPressed: () =>
                                    context.push('/profile/change-phone'),
                                text: localizations.changePhone,
                                isSecondary: true,
                              ),
                              AppCustomButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return const DeleteAccountDialog();
                                    },
                                  );
                                },
                                text: localizations.deleteAccount,
                                isDelete: true,
                                isLoading:
                                context
                                    .read<AuthCubit>()
                                    .state
                                is AuthLoading,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAccountInfoCard(BuildContext context, profile) {
    final localizations = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.accountInformation,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            context,
            Icons.phone_outlined,
            localizations.phone,
            profile.phone,
            textDirection: TextDirection.ltr,
          ),
          if (profile.extraPhones != null &&
              profile.extraPhones!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.add_ic_call_outlined,
              localizations.extraPhone,
              profile.extraPhones!,
              textDirection: TextDirection.ltr,
            ),
          ],
          if (profile.email != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.email_outlined,
              localizations.email,
              profile.email!,
            ),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.shield_outlined,
            localizations.status,
            profile.courier.isApproved
                ? (localizations.approved)
                : (localizations.pendingApproval),
            valueColor: profile.courier.isApproved
                ? Colors.green
                : Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.verified_user_outlined,
            localizations.phoneVerified,
            profile.isPhoneVerified ? (localizations.yes) : (localizations.no),
            valueColor: profile.isPhoneVerified ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context,
      IconData icon,
      String label,
      String value, {
        Color? valueColor,
        TextDirection? textDirection,
      }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.kPrimaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.kPrimaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                textDirection: textDirection,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF2D3436),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

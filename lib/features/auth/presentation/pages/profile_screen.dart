import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tawreedat_go/core/widgets/loading_screen.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/circel_back_button.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/delete_account_dialog.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/change_password_sheet.dart';
import '../../data/models/user_profile_model.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';
import '../../manager/profile_cubit.dart';
import '../../manager/profile_states.dart';
import '../widgets/profile_header_section.dart';
import '../widgets/edit_profile_bottom_sheet.dart';
import 'otp_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch profile after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileCubit>().fetchProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

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
            if (state is ProfileLinkSuccess) {
              showSuccessBanner(context, state.message);
            }
          },
          builder: (context, state) {
            final profile = context.read<ProfileCubit>().currentProfile;

            // Show loading only if we don't have cached data
            if (state is ProfileLoading && profile == null) {
              return const Center(child: LoadingScreen(isOne: true));
            }

            // Show error state only if we have no profile data at all
            if (profile == null && state is ProfileFailure) {
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
                    Text(state.message),
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

            // If we still don't have profile data and not loading, show retry button
            if (profile == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text('...'),
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
                await context.read<ProfileCubit>().fetchProfile();
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
                    leading: CircleBackButton(),
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
                      children: [
                        const SizedBox(height: 24),
                        _buildAccountInfoCard(context, profile),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Column(
                            children: [
                              // Change Phone — shown for social accounts (their only credential change)
                              // and also for local accounts
                              AppCustomButton(
                                onPressed: () =>
                                    _showChangeContactDialog(context, profile, 'phone'),
                                text: localizations.changePhone,
                                isSecondary: true,
                              ),
                              const SizedBox(height: 12),

                              // Change Email — local accounts only
                              // if (profile.loginType == 'LOCAL') ...[
                              //   AppCustomButton(
                              //     onPressed: () =>
                              //         _showChangeContactDialog(context, profile, 'email'),
                              //     text: localizations.changeEmail,
                              //     isSecondary: true,
                              //   ),
                              //   const SizedBox(height: 12),
                              // ],

                              if (profile.loginType == 'LOCAL')
                                AppCustomButton(
                                  onPressed: () {
                                    showChangePasswordBottomSheet(context);
                                  },
                                  text: localizations.changePassword,
                                  isSecondary: true,
                                  isLoading:
                                      context.read<AuthCubit>().state
                                          is AuthLoading,
                                ),
                              if (profile.loginType == 'LOCAL')
                                const SizedBox(height: 12),

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
                                    context.read<AuthCubit>().state
                                        is AuthLoading,
                              ),

                              // ── Link social accounts (LOCAL only) ──────────
                              if (profile.loginType == 'LOCAL') ...[
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.kPrimaryColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.link_rounded,
                                        size: 16,
                                        color: AppColors.kPrimaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            localizations.linkAccount,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2D3436),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            localizations.linkAccountSubtitle,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (profile.googleId == null) ...[
                                  _SocialLinkButton(
                                    label: localizations.linkGoogleAccount,
                                    assetPath: 'assets/images/login/google.svg',
                                    isLoading: context.watch<ProfileCubit>().state is ProfileLoading,
                                    onPressed: () => context.read<ProfileCubit>().linkWithGoogle(),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (Platform.isIOS && profile.appleId == null) ...[
                                  _SocialLinkButton(
                                    label: localizations.linkAppleAccount,
                                    assetPath: 'assets/images/login/apple.svg',
                                    isLoading: context.watch<ProfileCubit>().state is ProfileLoading,
                                    onPressed: () => context.read<ProfileCubit>().linkWithApple(),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],
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

  /// Shows a bottom sheet to collect the new phone/email, then launches the OTP screen.
  void _showChangeContactDialog(
    BuildContext context,
    UserProfileModel profile,
    String type,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final isPhone = type == 'phone';
    final controller = TextEditingController(
      text: isPhone ? (profile.phone ?? '') : (profile.email ?? ''),
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isPhone ? localizations.changePhone : localizations.changeEmail,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 20),
                AppTextFormField(
                  label: isPhone ? localizations.phone : localizations.email,
                  controller: controller,
                  isPhone: isPhone,
                  keyboardType:
                      isPhone ? TextInputType.phone : TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Flexible(
                      child: AppCustomButton(
                        isSecondary: true,
                        onPressed: () => Navigator.pop(sheetCtx),
                        text: localizations.cancel,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: AppCustomButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(sheetCtx);

                          final cubit = context.read<ProfileCubit>();
                          final navigator = Navigator.of(context);
                          final newValue = controller.text.trim();
                          final existingValue = isPhone
                              ? (profile.phone?.isNotEmpty == true ? profile.phone : null)
                              : (profile.email?.isNotEmpty == true ? profile.email : null);
                          final isFirstTime = existingValue == null;

                          if (isFirstTime) {
                            await cubit.addContactInfo(type: type, value: newValue);
                          } else {
                            await cubit.changeContactInfo(type: type, newValue: newValue);
                          }
                          if (!mounted) return;
                          if (cubit.state is ProfileFailure) return;

                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: cubit,
                                child: ProfileOtpScreen(
                                  oldDestination: existingValue,
                                  newDestination: newValue,
                                  onConfirmed: () => cubit.fetchProfile(),
                                  onSingleVerify: isFirstTime
                                      ? (code) => cubit.verifyNewContact(
                                            phone: isPhone ? newValue : null,
                                            email: isPhone ? null : newValue,
                                            code: code,
                                          )
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                        text: localizations.confirm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
            profile.phone ?? 'N/A',
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

          if (profile.email != null && profile.email!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.email_outlined,
              localizations.email,
              profile.email!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
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

class _SocialLinkButton extends StatelessWidget {
  final String label;
  final String assetPath;
  final VoidCallback onPressed;
  final bool isLoading;

  const _SocialLinkButton({
    required this.label,
    required this.assetPath,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SvgPicture.asset(assetPath, height: 24, width: 24),
                ],
              ),
      ),
    );
  }
}

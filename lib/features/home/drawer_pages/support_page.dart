import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../../core/utils/secure_storage_service.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../auth/data/models/user_profile_model.dart';
import '../../static_text/contact_us_manger.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  late Future<UserProfileModel?> _userProfileFuture;
  bool _loading = true;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _userProfileFuture = _loadUserProfile();
  }

  Future<UserProfileModel?> _loadUserProfile() async {
    final userProfileJson = await SecureStorageService().getUserProfile();
    if (userProfileJson != null) {
      return UserProfileModel.fromJson(userProfileJson);
    }
    return null;
  }

  Future<void> _load() async {
    await ContactUsManager().loadContacts();
    setState(() => _loading = false);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await ContactUsManager().sendMessage(
      name: await _userProfileFuture.then((value) => value?.fullName ?? ''),
      email: await _userProfileFuture.then((value) => value?.email ?? ''),
      message: text,
    );

    _controller.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SafeArea(
        top: false,
        child: Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.support),
            centerTitle: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.kPrimaryColor,
          ),
          body: _loading ? _buildLoadingState() : _buildContentState(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Skeletonizer(
      enabled: true,
      child: Column(
        children: [
          // Loading messages list
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (context, index) {
                final isAlternate = index % 2 == 0;

                return Column(
                  crossAxisAlignment: isAlternate
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Main message skeleton
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isAlternate
                            ? AppColors.kPrimaryColor.withOpacity(0.2)
                            : AppColors.kSecondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            color: Colors.grey.shade300,
                            margin: const EdgeInsets.only(bottom: 8),
                          ),
                          Container(
                            height: 14,
                            width: 200,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 10,
                                width: 80,
                                color: Colors.grey.shade300,
                              ),
                              if (isAlternate) ...[
                                const SizedBox(width: 4),
                                Container(
                                  height: 10,
                                  width: 20,
                                  color: Colors.grey.shade300,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Response skeleton (occasionally)
                    if (index % 3 == 0)
                      Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.kSecondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 14,
                              color: Colors.grey.shade300,
                              margin: const EdgeInsets.only(bottom: 8),
                            ),
                            Container(
                              height: 14,
                              width: 250,
                              color: Colors.grey.shade300,
                              margin: const EdgeInsets.only(bottom: 8),
                            ),
                            Container(
                              height: 10,
                              width: 150,
                              color: Colors.grey.shade300,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // Loading input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppColors.kBackgroundColor,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25.0),
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(0, 3),
                          blurRadius: 5,
                          color: Colors.grey.withOpacity(0.3),
                        ),
                      ],
                    ),
                    child: TextField(
                      enabled: false,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'your message...',
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: AppColors.kPrimaryColor,
                    ),
                    onPressed: null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentState() {
    final contacts = ContactUsManager().data?.contacts ?? [];

    return Column(
      children: [
        // Messages list
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final c = contacts[contacts.length - 1 - index];
              final isUser = c.response == null;

              return Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.kPrimaryColor.withOpacity(0.2)
                          : AppColors.kSecondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.message, style: AppTextStyles.regular14),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              textDirection: TextDirection.ltr,
                              timeago.format(c.createdAt),
                              style: AppTextStyles.regular14.copyWith(
                                fontSize: 10,
                                color: AppColors.kSecondaryColor.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                            if (isUser && c.read == true) ...[
                              const SizedBox(width: 4),
                              Text(
                                '✓✓',
                                style: AppTextStyles.regular14.copyWith(
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Admin response if exists
                  if (c.response != null && c.response!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.kSecondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.response!, style: AppTextStyles.regular14),
                          const SizedBox(height: 4),
                          Text(
                            'Replied ${timeago.format(c.updatedAt)}',
                            style: AppTextStyles.regular14.copyWith(
                              fontSize: 10,
                              color: AppColors.kSecondaryColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        // Input field
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppColors.kBackgroundColor,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25.0),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 3),
                        blurRadius: 5,
                        color: Colors.grey.withOpacity(0.3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'your message...',
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: AppColors.kPrimaryColor),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/style/app_colors.dart';
import 'package:tawreedat_courier/core/style/text_styles.dart';
import 'package:tawreedat_courier/core/widgets/loading_screen.dart';
import 'package:tawreedat_courier/l10n/app_localizations.dart';
import '../../../core/widgets/custom_button.dart';
import '../manager/delivery_areas_cubit.dart';
import '../data/delivery_areas_service.dart';

class SelectDeliveryAreasBottomSheet extends StatelessWidget {
  const SelectDeliveryAreasBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider(
        create: (context) =>
            DeliveryAreasCubit(DeliveryAreasService())..loadGovernorates(),
        child: const SelectDeliveryAreasBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.kSecondaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    localizations.deliveryAreas,
                    style: AppTextStyles.bold16.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: BlocBuilder<DeliveryAreasCubit, DeliveryAreasState>(
              builder: (context, state) {
                if (state is DeliveryAreasLoading) {
                  return Center(
                    child:LoadingScreen(isOne: true,)
                  );
                }

                if (state is DeliveryAreasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.message,
                          style: AppTextStyles.regular14,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context
                                .read<DeliveryAreasCubit>()
                                .loadGovernorates();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.kPrimaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(localizations.retry),
                        ),
                      ],
                    ),
                  );
                }

                if (state is GovernoratesLoaded) {
                  return _GovernoratesView(
                    governorates: state.governorates,
                    tempSelectedAreas: state.tempSelectedAreas,
                  );
                }

                if (state is AreasLoaded) {
                  return _AreasView(
                    governorate: state.governorate,
                    areas: state.areas,
                    tempSelectedAreas: state.tempSelectedAreas,
                  );
                }

                if (state is DeliveryAreasSaved) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localizations.profileUpdatedSuccessfully),
                        backgroundColor: Colors.green,
                      ),
                    );
                  });
                  return Center(child: LoadingScreen(isOne: true));
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          // Save Button
          BlocBuilder<DeliveryAreasCubit, DeliveryAreasState>(
            builder: (context, state) {
              final hasSelections =
                  state is AreasLoaded && state.tempSelectedAreas.isNotEmpty;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: AppCustomButton(
                    onPressed: () {
                      if (!hasSelections) return;
                      context.read<DeliveryAreasCubit>().saveSelectedAreas();
                    },
                    text: localizations.confirm,
                    isLoading: state is DeliveryAreasSaving,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GovernoratesView extends StatelessWidget {
  final List<dynamic> governorates;
  final Map<String, dynamic> tempSelectedAreas;

  const _GovernoratesView({
    required this.governorates,
    required this.tempSelectedAreas,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            localizations.chooseGovernate,
            style: AppTextStyles.bold16.copyWith(
              color: AppColors.kSecondaryColor,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: governorates.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final governorate = governorates[index];
              final isArabic = localizations.localeName == 'ar';
              final governorateName = isArabic
                  ? governorate.nameAr
                  : governorate.name;

              // Check if this governorate has any selected areas
              final hasSelectedAreas = tempSelectedAreas.values.any(
                (area) => area.governorateId == governorate.id,
              );

              return ListTile(
                onTap: () {
                  context.read<DeliveryAreasCubit>().loadAreasByGovernorate(
                    governorate.id,
                  );
                },
                title: Text(governorateName, style: AppTextStyles.bold16),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasSelectedAreas)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.kSecondaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tempSelectedAreas.values
                              .where(
                                (area) => area.governorateId == governorate.id,
                              )
                              .length
                              .toString(),
                          style: AppTextStyles.bold16.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.kPrimaryColor,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AreasView extends StatelessWidget {
  final dynamic governorate;
  final List<dynamic> areas;
  final Map<String, dynamic> tempSelectedAreas;

  const _AreasView({
    required this.governorate,
    required this.areas,
    required this.tempSelectedAreas,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = localizations.localeName == 'ar';
    final governorateName = isArabic ? governorate.nameAr : governorate.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button and title
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.kPrimaryColor),
                onPressed: () {
                  context.read<DeliveryAreasCubit>().loadGovernorates();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.chooseArea,
                      style: AppTextStyles.bold16.copyWith(
                        color: AppColors.kSecondaryColor,
                      ),
                    ),
                    Text(
                      governorateName,
                      style: AppTextStyles.regular14.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Selected count
        if (tempSelectedAreas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.kSecondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.kSecondaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${tempSelectedAreas.length} ${localizations.areasSelected}',
                    style: AppTextStyles.bold16.copyWith(
                      color: AppColors.kSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Areas list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: areas.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final area = areas[index];
              final areaName = isArabic ? area.nameAr : area.name;
              final key = '${governorate.id}_${area.id}';
              final isSelected = tempSelectedAreas.containsKey(key);

              return CheckboxListTile(
                value: isSelected,
                onChanged: (value) {
                  context.read<DeliveryAreasCubit>().toggleAreaSelection(
                    governorate.id,
                    area.id,
                  );
                },
                title: Text(
                  areaName,
                  style: AppTextStyles.regular14.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                activeColor: AppColors.kPrimaryColor,
                checkColor: Colors.white,
                controlAffinity: ListTileControlAffinity.trailing,
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              );
            },
          ),
        ),
      ],
    );
  }
}

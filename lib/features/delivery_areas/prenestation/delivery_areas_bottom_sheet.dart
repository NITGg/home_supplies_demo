import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/style/app_colors.dart';
import 'package:tawreedat_courier/core/style/text_styles.dart';
import 'package:tawreedat_courier/core/widgets/loading_screen.dart';
import 'package:tawreedat_courier/l10n/app_localizations.dart';
import '../../../core/widgets/custom_button.dart';
import '../data/models/delivery_areas_models.dart';
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
        create: (_) =>
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          /// ================= HEADER =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.kSecondaryColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.tight,
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

          /// ================= SELECTED CHIPS (ALWAYS VISIBLE) =================
          BlocBuilder<DeliveryAreasCubit, DeliveryAreasState>(
            builder: (context, state) {
              Map<String, SelectedAreaWithDetails> selected = {}; // ✅ Changed type

              if (state is GovernoratesLoaded) {
                selected = state.tempSelectedAreas;
              } else if (state is AreasLoaded) {
                selected = state.tempSelectedAreas;
              }

              return _SelectedAreasChips(selectedAreas: selected); // ✅ Fixed variable name
            },
          ),

          /// ================= CONTENT =================
          Flexible(
            fit: FlexFit.tight,
            child: BlocBuilder<DeliveryAreasCubit, DeliveryAreasState>(
              builder: (context, state) {
                if (state is DeliveryAreasLoading) {
                  return const Center(
                    child: LoadingScreen(isOne: true),
                  );
                }

                if (state is DeliveryAreasError) {
                  return Center(
                    child: Text(state.message),
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
                        content:
                        Text(localizations.profileUpdatedSuccessfully),
                        backgroundColor: Colors.green,
                      ),
                    );
                  });

                  return const LoadingScreen(isOne: true);
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          /// ================= SAVE BUTTON =================
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
                    onPressed: (){
                      if(hasSelections){
                        context
                            .read<DeliveryAreasCubit>()
                            .saveSelectedAreas();
                      }
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

////////////////////////////////////////////////////////////////
/// 🔹 SELECTED AREAS CHIPS (NEW UX)
////////////////////////////////////////////////////////////////

class _SelectedAreasChips extends StatelessWidget {
  final Map<String, SelectedAreaWithDetails> selectedAreas; // ✅ Changed type

  const _SelectedAreasChips({required this.selectedAreas});

  @override
  Widget build(BuildContext context) {
    if (selectedAreas.isEmpty) return const SizedBox.shrink();

    final localizations = AppLocalizations.of(context)!;
    final cubit = context.read<DeliveryAreasCubit>();
    final isArabic = localizations.localeName == 'ar';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.kSecondaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.kSecondaryColor.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${selectedAreas.length} ${localizations.areasSelected}',
            style: AppTextStyles.bold16.copyWith(
              fontSize: 13,
              color: AppColors.kSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            width: double.infinity, // ✅ Fixed constraint issue
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selectedAreas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final area = selectedAreas.values.elementAt(index);

                return Chip(
                  label: Text(
                    isArabic ? area.nameAr : area.name, // ✅ Now works!
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.white,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
////////////////////////////////////////////////////////////////
/// GOVERNORATES VIEW
////////////////////////////////////////////////////////////////

class _GovernoratesView extends StatelessWidget {
  final List<Governorate> governorates; // ✅ Changed from dynamic
  final Map<String, SelectedAreaWithDetails> tempSelectedAreas; // ✅ Changed type

  const _GovernoratesView({
    required this.governorates,
    required this.tempSelectedAreas,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = localizations.localeName == 'ar';

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: governorates.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final g = governorates[index];
        final name = isArabic ? g.nameAr : g.name;

        final count = tempSelectedAreas.values
            .where((e) => e.governorateId == g.id)
            .length;

        return ListTile(
          title: Text(name, style: AppTextStyles.bold16),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0)
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.kSecondaryColor,
                  child: Text(
                    count.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
          onTap: () {
            context
                .read<DeliveryAreasCubit>()
                .loadAreasByGovernorate(g.id);
          },
        );
      },
    );
  }
}

////////////////////////////////////////////////////////////////
/// AREAS VIEW
////////////////////////////////////////////////////////////////

class _AreasView extends StatelessWidget {
  final Governorate governorate; // ✅ Changed from dynamic
  final List<Area> areas; // ✅ Changed from dynamic
  final Map<String, SelectedAreaWithDetails> tempSelectedAreas; // ✅ Changed type

  const _AreasView({
    required this.governorate,
    required this.areas,
    required this.tempSelectedAreas,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context)!.localeName == 'ar';

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: areas.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final area = areas[index];
        final name = isArabic ? area.nameAr : area.name;

        final key = '${governorate.id}_${area.id}';
        final selected = tempSelectedAreas.containsKey(key);

        return CheckboxListTile(
          value: selected,
          onChanged: (_) {
            context.read<DeliveryAreasCubit>().toggleAreaSelection(
              governorate.id,
              area.id,
            );
          },
          title: Text(name),
          activeColor: AppColors.kPrimaryColor,
        );
      },
    );
  }
}
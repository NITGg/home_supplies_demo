import 'package:equatable/equatable.dart';

import '../data/models/category_models.dart';

sealed class CategoriesState extends Equatable {
  const CategoriesState();

  @override
  List<Object?> get props => [];
}

class CategoriesInitial extends CategoriesState {
  const CategoriesInitial();
}

class CategoriesLoading extends CategoriesState {
  const CategoriesLoading();
}

class CategoriesLoaded extends CategoriesState {
  final List<CategoryModel> categories;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  const CategoriesLoaded({
    required this.categories,
    required this.totalCount,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  CategoriesLoaded copyWith({
    List<CategoryModel>? categories,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return CategoriesLoaded(
      categories: categories ?? this.categories,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props =>
      [categories, totalCount, hasMore, isLoadingMore];
}

class CategoriesError extends CategoriesState {
  final String message;

  const CategoriesError(this.message);

  @override
  List<Object?> get props => [message];
}
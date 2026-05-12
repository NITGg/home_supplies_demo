import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tawreedat_go/features/products/data/models/product_model.dart';
import 'package:tawreedat_go/features/products/data/repo/product_repo.dart';
import 'package:tawreedat_go/features/products/manager/product_detail_cubit.dart';
import 'package:tawreedat_go/features/products/manager/product_details_states.dart';
import 'package:tawreedat_go/features/suppliers/data/models/supplier_models.dart';
import 'package:tawreedat_go/features/suppliers/data/repo/supplier_repo.dart';

class MockProductRepository extends Mock implements ProductRepository {}
class MockSupplierRepository extends Mock implements SupplierRepository {}

// Minimal ProductModel stub — only required fields
ProductModel _makeProduct({int? supplierId}) => ProductModel(
  id: 1,
  name: 'Test Product',
  price: 10.0,
  stock: 5,
  minStock: 1,
  sku: 'SKU-001',
  images: const [],
  isActive: true,
  isFeatured: false,
  categoryId: 1,
  supplierId: supplierId,
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
  rating: 4.5,
  totalReviews: 10,
  isBestSeller: false,
  sortId: 0,
  slug: 'test-product',
  attributes: const [],
  units: const [],
);

SupplierModel _makeSupplier() => const SupplierModel(
  id: 42,
  isApproved: true,
  user: SupplierUserModel(
    id: 1,
    fullName: 'Test Supplier',
    phone: '0100000000',
  ),
);

void main() {
  late MockProductRepository productRepo;
  late MockSupplierRepository supplierRepo;

  setUp(() {
    productRepo = MockProductRepository();
    supplierRepo = MockSupplierRepository();
  });

  group('ProductDetailCubit', () {
    blocTest<ProductDetailCubit, ProductDetailState>(
      'load emits Loading then Loaded on success (no supplierId)',
      build: () {
        when(() => productRepo.getProductById(1, supplierId: any(named: 'supplierId')))
            .thenAnswer((_) async => _makeProduct());
        return ProductDetailCubit(
          repository: productRepo,
          supplierRepository: supplierRepo,
        );
      },
      act: (c) => c.load(1),
      expect: () => [
        const ProductDetailLoading(),
        isA<ProductDetailLoaded>(),
      ],
      verify: (c) {
        final state = c.state as ProductDetailLoaded;
        expect(state.product.id, 1);
        expect(state.isSupplierOpen, isTrue);
      },
    );

    blocTest<ProductDetailCubit, ProductDetailState>(
      'load emits Loading then Loaded, fetches supplier when supplierId present',
      build: () {
        when(() => productRepo.getProductById(1, supplierId: any(named: 'supplierId')))
            .thenAnswer((_) async => _makeProduct(supplierId: 42));
        when(() => supplierRepo.getSupplierById(42))
            .thenAnswer((_) async => _makeSupplier());
        return ProductDetailCubit(
          repository: productRepo,
          supplierRepository: supplierRepo,
        );
      },
      act: (c) => c.load(1),
      expect: () => [
        const ProductDetailLoading(),
        isA<ProductDetailLoaded>(),
      ],
      verify: (_) => verify(() => supplierRepo.getSupplierById(42)).called(1),
    );

    blocTest<ProductDetailCubit, ProductDetailState>(
      'load emits Loading then Error on product fetch failure',
      build: () {
        when(() => productRepo.getProductById(any(), supplierId: any(named: 'supplierId')))
            .thenThrow(Exception('Network error'));
        return ProductDetailCubit(
          repository: productRepo,
          supplierRepository: supplierRepo,
        );
      },
      act: (c) => c.load(99),
      expect: () => [
        const ProductDetailLoading(),
        isA<ProductDetailError>(),
      ],
    );

    blocTest<ProductDetailCubit, ProductDetailState>(
      'supplier fetch failure defaults isSupplierOpen to true',
      build: () {
        when(() => productRepo.getProductById(1, supplierId: any(named: 'supplierId')))
            .thenAnswer((_) async => _makeProduct(supplierId: 42));
        when(() => supplierRepo.getSupplierById(42))
            .thenThrow(Exception('Supplier unavailable'));
        return ProductDetailCubit(
          repository: productRepo,
          supplierRepository: supplierRepo,
        );
      },
      act: (c) => c.load(1),
      expect: () => [
        const ProductDetailLoading(),
        isA<ProductDetailLoaded>(),
      ],
      verify: (c) {
        final state = c.state as ProductDetailLoaded;
        expect(state.isSupplierOpen, isTrue);
      },
    );
  });
}

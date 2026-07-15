import 'package:dio/dio.dart';

import '../../core/utils/api_client.dart';

/// MODEL
class ContactModel {
  final int id;
  final String name;
  final String email;
  final String message;
  final String? response;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool read;

  ContactModel({
    required this.id,
    required this.name,
    required this.email,
    required this.message,
    this.response,
    required this.createdAt,
    required this.updatedAt,
    required this.read,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      message: json['message'] ?? '',
      response: json['response'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      read: json['read'] ?? false,
    );
  }
}

/// RESPONSE WRAPPER
class ContactsResponse {
  final List<ContactModel> contacts;
  final int totalPages;
  final int totalCount;

  ContactsResponse({
    required this.contacts,
    required this.totalPages,
    required this.totalCount,
  });

  factory ContactsResponse.fromJson(Map<String, dynamic> json) {
    final contactsList =
        (json['contacts'] as List?)
            ?.map((e) => ContactModel.fromJson(e))
            .toList() ??
        [];

    return ContactsResponse(
      contacts: contactsList,
      totalPages: json['totalPages'] ?? 0,
      totalCount: json['totalCount'] ?? 0,
    );
  }
}

/// MANAGER
class ContactUsManager {
  static final ContactUsManager _instance = ContactUsManager._internal();

  factory ContactUsManager() => _instance;

  ContactUsManager._internal();

  ContactsResponse? _contactsResponse;
  final Dio _dio = ApiClient.instance.dio2;

  ContactsResponse? get data => _contactsResponse;

  Future<void> loadContacts() async {
    final res = await _dio.get('/contact-us');
    if (res.statusCode == 200) {
      _contactsResponse = ContactsResponse.fromJson(res.data);
    }
  }

  Future<void> sendMessage({
    required String name,
    required String email,
    required String message,
  }) async {
    await _dio.post(
      '/contact-us',
      data: {'name': name, 'email': email, 'message': message},
    );
  }

  // Future<void> updateMessage({required int id, required String message}) async {
  //   await _dio.put(
  //     '/api/contact-us/$id',
  //     data: {'message': message},
  //     options: Options(
  //       headers: {'Authorization': 'Bearer ${SecureStorageService().getToken}'},
  //     ),
  //   );
  // }
  //
  // Future<void> deleteMessage(int id) async {
  //   await _dio.delete(
  //     '/api/contact-us/$id',
  //     options: Options(
  //       headers: {'Authorization': 'Bearer ${SecureStorageService().getToken}'},
  //     ),
  //   );
  // }
}

import '../models/admin_users_model.dart';

class AdminUsersController {
  const AdminUsersController();

  Stream<List<AdminUserData>> getCustomers() => AdminUsersModel.streamCustomers();
  Stream<List<AdminUserData>> getApprovedProviders() =>
      AdminUsersModel.streamApprovedProviders();

  Future<void> setSuspended(AdminUserData user, bool suspended) =>
      AdminUsersModel.setSuspended(user, suspended);
}

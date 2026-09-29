import '../models/admin_users_model.dart';

class AdminUsersController {
  const AdminUsersController();

  Stream<List<AdminUserData>> getCustomers() {
    return AdminUsersModel.streamCustomers();
  }

  Stream<List<AdminUserData>> getApprovedProviders() {
    return AdminUsersModel.streamApprovedProviders();
  }
}
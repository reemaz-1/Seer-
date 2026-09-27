import '../models/provider_registration_request.dart';

class RegistrationRequestsController {
  // Story #52
  Stream<List<ProviderRegistrationRequest>> getRequestsList() {
    return ProviderRegistrationRequest.streamAll();
  }

  // Story #51
  Future<ProviderRegistrationRequest?> getRequestDetails(String requestId) {
    return ProviderRegistrationRequest.fetchById(requestId);
  }

  // Story #53
  Future<void> approveRequest(String requestId) {
    return ProviderRegistrationRequest.updateStatus(requestId, 'approved');
  }

  Future<void> rejectRequest(String requestId) {
    return ProviderRegistrationRequest.updateStatus(requestId, 'rejected');
  }
}
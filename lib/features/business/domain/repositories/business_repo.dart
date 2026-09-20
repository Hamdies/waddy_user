import 'package:get/get.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/business/domain/models/business_plan_body.dart';
import 'package:waddy_app/features/business/domain/models/package_model.dart';
import 'package:waddy_app/features/business/domain/repositories/business_repo_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

class BusinessRepo implements BusinessRepoInterface<dynamic> {
  final ApiClient apiClient;

  BusinessRepo({required this.apiClient});

  @override
  Future<Response> setUpBusinessPlan(BusinessPlanBody businessPlanBody) async {
    return await apiClient.postData(
      AppConstants.businessPlanUri,
      businessPlanBody.toJson(),
    );
  }

  @override
  Future<Response> subscriptionPayment(String id, String? paymentName) async {
    // Web-only redirect target; on mobile the gateway runs inside
    // PaymentWebViewScreen and OrderService.paymentRedirect matches the
    // backend's own subscription-{success,fail,cancel} URLs instead.
    return await apiClient.postData(AppConstants.businessPlanPaymentUri, {
      'id': id,
      'payment_gateway': paymentName,
      'callback': '',
    });
  }

  @override
  Future<PackageModel?> getList({int? offset}) async {
    PackageModel? packageModel;
    Response response = await apiClient.getData(AppConstants.storePackagesUri);
    if (response.statusCode == 200) {
      packageModel = PackageModel.fromJson(response.body);
    }
    return packageModel;
  }

  @override
  Future add(dynamic value) {
    throw UnimplementedError();
  }

  @override
  Future delete(int? id) {
    throw UnimplementedError();
  }

  @override
  Future get(String? id) {
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body, int? id) {
    throw UnimplementedError();
  }
}

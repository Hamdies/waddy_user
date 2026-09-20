import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/business/domain/models/business_plan_body.dart';
import 'package:waddy_app/features/business/domain/models/package_model.dart';
import 'package:waddy_app/features/business/domain/repositories/business_repo_interface.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'business_service_interface.dart';

class BusinessService implements BusinessServiceInterface {
  final BusinessRepoInterface businessRepoInterface;
  BusinessService({required this.businessRepoInterface});

  @override
  Future<PackageModel?> getPackageList() async {
    return await businessRepoInterface.getList();
  }

  @override
  Future<String> processesBusinessPlan(
    String businessPlanStatus,
    int paymentIndex,
    int storeId,
    String? digitalPaymentName,
    int? selectedPackageId,
  ) async {
    // if (packageModel!.packages!.isNotEmpty) {
    //
    //
    //
    // } else if(packageModel.packages!.isEmpty && packageModel.packages!.isEmpty){
    //   showCustomSnackBar('no_package_found'.tr);
    // } else {
    //   showCustomSnackBar('please Select Any Process');
    // }
    String businessPlan = 'subscription';
    int? packageId = selectedPackageId;
    String? payment = paymentIndex == 0 ? 'free_trial' : digitalPaymentName;

    if (paymentIndex == 1 && digitalPaymentName == null) {
      showCustomSnackBar('please_select_payment_method'.tr);
    } else {
      businessPlanStatus = await setUpBusinessPlan(
        BusinessPlanBody(
          businessPlan: businessPlan,
          packageId: packageId.toString(),
          storeId: storeId.toString(),
          payment: payment,
          paymentGateway: payment,
          callBack: paymentIndex == 0 ? '' : RouteHelper.subscriptionSuccess,
          paymentPlatform: 'app',
          type: 'new_join',
        ),
        digitalPaymentName,
        businessPlanStatus,
        storeId,
      );
    }
    return businessPlanStatus;
  }

  @override
  Future<String> setUpBusinessPlan(
    BusinessPlanBody businessPlanBody,
    String? digitalPaymentName,
    String businessPlanStatus,
    int storeId,
  ) async {
    Response response = await businessRepoInterface.setUpBusinessPlan(
      businessPlanBody,
    );
    if (response.statusCode == 200) {
      if (response.body['redirect_link'] != null) {
        _subscriptionPayment(
          response.body['redirect_link'],
          digitalPaymentName,
          storeId,
        );
      } else {
        businessPlanStatus = 'complete';
        Get.find<HomeController>().saveRegistrationSuccessfulSharedPref(true);
        Get.find<HomeController>().saveIsStoreRegistrationSharedPref(true);
        Get.offAllNamed(
          RouteHelper.getSubscriptionSuccessRoute(
            status: 'success',
            fromSubscription: true,
            storeId: storeId,
          ),
        );
      }
    }
    return businessPlanStatus;
  }

  Future<void> _subscriptionPayment(
    String redirectUrl,
    String? digitalPaymentName,
    int storeId,
  ) async {
    Get.toNamed(
      RouteHelper.getPaymentRoute(
        '0',
        0,
        '',
        0,
        false,
        digitalPaymentName,
        subscriptionUrl: redirectUrl,
        guestId: '',
        storeId: storeId,
      ),
    );
  }
}

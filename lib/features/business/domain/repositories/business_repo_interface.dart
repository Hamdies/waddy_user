import 'package:get/get_connect/connect.dart';
import 'package:waddy_app/features/business/domain/models/business_plan_body.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class BusinessRepoInterface<T> implements RepositoryInterface<T> {
  Future<Response> setUpBusinessPlan(BusinessPlanBody businessPlanBody);
  Future<Response> subscriptionPayment(String id, String? paymentName);
}
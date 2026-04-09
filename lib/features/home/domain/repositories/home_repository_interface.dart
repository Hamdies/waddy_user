import 'package:waddy_app/features/home/domain/models/cashback_model.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class HomeRepositoryInterface<T> implements RepositoryInterface {
  Future<CashBackModel?> getCashBackData(double amount);
  Future<bool> saveRegistrationSuccessful(bool status);
  Future<bool> saveIsRestaurantRegistration(bool status);
  bool getRegistrationSuccessful();
  bool getIsRestaurantRegistration();
}
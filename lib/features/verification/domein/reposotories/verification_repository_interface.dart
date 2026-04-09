import 'package:get/get.dart';
import 'package:waddy_app/common/models/response_model.dart';
import 'package:waddy_app/features/verification/domein/models/verification_data_model.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class VerificationRepositoryInterface<T> extends RepositoryInterface<T>{
  Future<ResponseModel> forgetPassword({String? phone, String? email});
  Future<ResponseModel> resetPassword({String? resetToken, String? phone, String? email, required String password, required String confirmPassword});
  Future<Response> verifyPhone(VerificationDataModel data);
  Future<ResponseModel> verifyToken({String? phone, String? email, required String token});
  Future<ResponseModel> verifyFirebaseOtp({required String phoneNumber, required String session, required String otp, required String loginType});
  Future<ResponseModel> verifyForgetPassFirebaseOtp({required String phoneNumber, required String session, required String otp});
}
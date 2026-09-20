import 'package:image_picker/image_picker.dart';
import 'package:waddy_app/common/models/response_model.dart';
import 'package:waddy_app/features/profile/domain/models/update_user_model.dart';
import 'package:waddy_app/features/profile/domain/models/userinfo_model.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class ProfileRepositoryInterface extends RepositoryInterface {
  //Future<dynamic> updateProfile(UserInfoModel userInfoModel, XFile? data, String token);
  Future<ResponseModel> updateProfile(
    UpdateUserModel userInfoModel,
    XFile? data,
    String token,
  );
  Future<dynamic> changePassword(UserInfoModel userInfoModel);
}

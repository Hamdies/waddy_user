import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class FavouriteRepositoryInterface<ResponseModel>
    implements RepositoryInterface<ResponseModel> {
  @override
  Future<ResponseModel> add(dynamic a, {bool isStore = false, int? id});
  @override
  Future<ResponseModel> delete(int? id, {bool isStore = false});
}

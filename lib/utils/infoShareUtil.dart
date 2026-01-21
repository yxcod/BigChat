import 'package:get/get.dart';
import '../model/userInfoModel.dart';

class InfoShareUtil extends GetxController {
  //用户信息
  Rx<UserInfoModel> userInfo = UserInfoModel.formJSON({}).obs;
  //存储token
  Rx<String> Token = "".obs;
  updateInfo(UserInfoModel userInfoModel, String token) {
    userInfo.value = userInfoModel;
    Token.value = token;
  }
}

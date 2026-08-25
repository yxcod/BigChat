import '../model/userInfoModel.dart';

import '../utils/http.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/parsing/json_value_parser.dart';

Future<UserInfoModel> getUserInfoApi(String userName) async {
  try {
    Response response = await HttpUtil().post(
      '/api/user/userInfo',
      data: {'userName': userName},
    );
    //debugPrint('POST请求成功：${response.data}');
    final mapData = response.data as Map<String, dynamic>;

    // 检查后端返回的code值
    final code = mapData.containsKey('code')
        ? JsonValueParser.intValue(mapData['code'], fallback: -1)
        : null;
    if (code != null) {
      if (code == 101) {
        // code为101表示未查询到好友信息
        throw Exception('未查询到好友信息');
      } else if (code == 100) {
        // code为100表示成功查询到用户信息，继续处理
      } else if (code != 200) {
        // 其他错误码
        throw Exception('请求失败，错误码：$code');
      }
    }

    //返回model类
    return UserInfoModel.formJSON(mapData);
  } on DioException catch (e) {
    debugPrint('POST请求失败：${e.error}');
    // 抛出异常或返回错误信息
    throw Exception(e.error);
  }
  //return UserInfoModel();
}

// 更新用户信息的API函数
Future<int> updateUserInfoApi(UserInfoModel userInfo) async {
  try {
    // 构建请求参数，只包含userName、nickName、signature
    Map<String, dynamic> requestData = {
      'userName': userInfo.userName,
      'nickName': userInfo.nickName,
      'signature': userInfo.signature,
      'avater': userInfo.avatar,
      'gender': userInfo.gender,
      'region': userInfo.region,
    };

    Response response = await HttpUtil().post(
      '/api/user/userInfoModify', // 假设后端接口路径为/api/user/updateUserInfo
      data: requestData,
    );

    debugPrint('更新用户信息请求成功：${response.data}');
    final mapData = response.data as Map<String, dynamic>;
    // 解析并返回code值，默认为-1表示解析失败
    return JsonValueParser.intValue(mapData['code'], fallback: -1);
  } on DioException catch (e) {
    debugPrint('更新用户信息请求失败：${e.error}');
    // 抛出异常
    throw Exception(e.error);
  }
}

// 更改用户密码的API函数
Future<int> changePasswordApi(
  String userName,
  String oldPassword,
  String newPassword,
) async {
  try {
    // 构建请求参数，包含userName、oldPassword、newPassword
    Map<String, dynamic> requestData = {
      'userName': userName,
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    };

    Response response = await HttpUtil().post(
      '/api/user/passwordModify', // 假设后端接口路径为/api/user/changePassword
      data: requestData,
    );

    debugPrint('更改密码请求成功：${response.data}');
    final mapData = response.data as Map<String, dynamic>;
    // 解析并返回code值，默认为-1表示解析失败
    return JsonValueParser.intValue(mapData['code'], fallback: -1);
  } on DioException catch (e) {
    debugPrint('更改密码请求失败：${e.error}');
    // 抛出异常
    throw Exception(e.error);
  }
}

// 忘记密码页面使用的密码重置接口。安全码由前端页面校验，接口只接收账号和新密码。
Future<int> resetPasswordApi(String userName, String newPassword) async {
  try {
    final response = await HttpUtil().post(
      '/api/user/passwordReset',
      data: {'userName': userName, 'newPassword': newPassword},
    );
    final mapData = response.data as Map<String, dynamic>;
    return JsonValueParser.intValue(mapData['code'], fallback: -1);
  } on DioException catch (error) {
    debugPrint('重置密码请求失败：${error.error}');
    throw Exception(error.error);
  }
}

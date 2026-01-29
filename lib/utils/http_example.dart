import 'package:dio/dio.dart';
import './http.dart';

// 示例：使用HttpUtil进行网络请求
class HttpExample {
  // 示例1：GET请求
  static Future<void> getExample() async {
    try {
      Response response = await HttpUtil().get(
        '/users',
        queryParameters: {'page': 1, 'limit': 10},
      );
      print('GET请求成功：${response.data}');
    } on DioException catch (e) {
      print('GET请求失败：${e.error}');
    }
  }

  // 示例2：POST请求
  static Future<void> postExample() async {
    try {
      Response response = await HttpUtil().post(
        '/login',
        data: {'username': 'test', 'password': '123456'},
      );
      print('POST请求成功：${response.data}');
    } on DioException catch (e) {
      print('POST请求失败：${e.error}');
    }
  }

  // 示例3：PUT请求
  static Future<void> putExample() async {
    try {
      Response response = await HttpUtil().put(
        '/users/1',
        data: {'name': 'Updated Name', 'email': 'updated@example.com'},
      );
      print('PUT请求成功：${response.data}');
    } on DioException catch (e) {
      print('PUT请求失败：${e.error}');
    }
  }

  // 示例4：DELETE请求
  static Future<void> deleteExample() async {
    try {
      Response response = await HttpUtil().delete('/users/1');
      print('DELETE请求成功：${response.data}');
    } on DioException catch (e) {
      print('DELETE请求失败：${e.error}');
    }
  }
}

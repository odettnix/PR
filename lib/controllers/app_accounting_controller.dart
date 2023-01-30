import 'dart:io';

import 'package:conduit/conduit.dart';

import '../model/ModelResponse.dart';
import '../model/accounting.dart';
import '../model/history.dart';
import '../model/user.dart';
import '../utils/AppUtils.dart';
import '../utils/app_response.dart';

class AppAccountingController extends ResourceController {
  AppAccountingController(this.managedContext);

  final ManagedContext managedContext;

  @Operation.post()
  Future<Response> createAccounting(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.body() Accounting accounting) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final accountingQuery = Query<Accounting>(managedContext)
        ..where((accounting) => accounting.user!.id).equalTo(id);
      final accountings = await accountingQuery.fetch();

      final accountingNumber = accountings.length;

      final fUser = Query<User>(managedContext)
        ..where((user) => user.id).equalTo(id);

      final user = await fUser.fetchOne();
      createHistory(id, "Новый учет создан");

      await managedContext.transaction((transaction) async {
        final qCreateAccounting = Query<Accounting>(transaction)
          ..values.numberOperation = accountingNumber + 1
          ..values.nameOperation = accounting.nameOperation
          ..values.description = accounting.description
          ..values.category = accounting.category
          ..values.dateOfOperation = DateTime.now().toString()
          ..values.transactionAmount = accounting.transactionAmount
          ..values.deleted = false
          ..values.user = user;

        await qCreateAccounting.insert();
      });

      return AppResponse.ok(message: 'Успешное создание учета');
    } catch (error) {
      return AppResponse.serverError(error, message: 'Ошибка создания учета');
    }
  }

  @Operation.get()
  Future<Response> getAccountings(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      {@Bind.query("deleted") int? deleted}) async {
    try {
      final id = AppUtils.getIdFromHeader(header);

      Query<Accounting>? qAccountings;

      qAccountings = Query<Accounting>(managedContext)
        ..where((accounting) => accounting.user!.id).equalTo(id);

      if (deleted == 0) {
        qAccountings.where((accounting) => accounting.deleted).equalTo(false);
      } else if (deleted == 1) {
        qAccountings.where((accounting) => accounting.deleted).equalTo(true);
      }

      final List<Accounting> accountingList = await qAccountings.fetch();

      if (accountingList.isEmpty) {
        return AppResponse.ok(message: "Заметки не найдены");
      }

      return Response.ok(accountingList);
    } catch (e) {
      return AppResponse.serverError(e);
    }
  }

  @Operation.get("id")
  Future<Response> getAccounting(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.path("id") int id,
      {@Bind.query("delete") bool? delete}) async {
    try {
      final currentUserId = AppUtils.getIdFromHeader(header);
      final deletedAccountingQuery = Query<Accounting>(managedContext)
        ..where((accounting) => accounting.id).equalTo(id)
        ..where((accounting) => accounting.user!.id).equalTo(currentUserId)
        ..where((accounting) => accounting.deleted).equalTo(true);
      final deletedAccounting = await deletedAccountingQuery.fetchOne();
      String message = "Запись получена";
      if (deletedAccounting != null && delete != null && delete) {
        deletedAccountingQuery.values.deleted = false;
        deletedAccountingQuery.update();
        message = "Учет восстановлен";
        createHistory(
          currentUserId,
          "Учет с id $id восстановлен",
        );
      }
      final currentAuthorId = AppUtils.getIdFromHeader(header);
      final accountingg =
          await managedContext.fetchObjectWithID<Accounting>(id);
      if (accountingg == null) {
        return AppResponse.ok(message: "Учет не найден");
      }
      if (accountingg.user?.id != currentAuthorId ||
          accountingg.deleted == true) {
        return AppResponse.ok(message: "Нет доступа к учету");
      }
      accountingg.backing.removeProperty("user");
      return AppResponse.ok(
          body: accountingg.backing.contents, message: message);
    } catch (error) {
      return AppResponse.serverError(error, message: "Ошибка вывода учета");
    }
  }

  @Operation.put("id")
  Future<Response> updateAccounting(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.path("id") int id,
      @Bind.body() Accounting accounting) async {
    try {
      final currentUserId = AppUtils.getIdFromHeader(header);
      final accountingQuery = Query<Accounting>(managedContext)
        ..where((accounting) => accounting.id).equalTo(id)
        ..where((accounting) => accounting.user!.id).equalTo(currentUserId)
        ..where((accounting) => accounting.deleted).equalTo(false);
      final accountingBase = await accountingQuery.fetchOne();
      if (accountingBase == null) {
        return AppResponse.ok(message: "Учет не найдет");
      }
      final qUpdateAccounting = Query<Accounting>(managedContext)
        ..where((accounting) => accounting.id).equalTo(accountingBase.id)
        ..values.nameOperation = accounting.nameOperation
        ..values.description = accounting.description
        ..values.category = accounting.category
        ..values.transactionAmount = accounting.transactionAmount;
      await qUpdateAccounting.update();
      createHistory(currentUserId, "Учет с id $id изменен");
      return AppResponse.ok(
          body: accounting.backing.contents,
          message: "Успешное обновление учета");
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка получения учета');
    }
  }

  @Operation.delete("id")
  Future<Response> deleteAccounting(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.path("id") int id,
  ) async {
    try {
      final currentUserId = AppUtils.getIdFromHeader(header);
      final accountingQuery = Query<Accounting>(managedContext)
        ..where((accounting) => accounting.id).equalTo(id)
        ..where((accounting) => accounting.user!.id).equalTo(currentUserId)
        ..where((accounting) => accounting.deleted).equalTo(false);
      final accountingBase = await accountingQuery.fetchOne();
      if (accountingBase == null) {
        return AppResponse.ok(message: "Учет не найдет");
      }
      final qUpdateAccounting = Query<Accounting>(managedContext)
        ..where((accounting) => accounting.id).equalTo(accountingBase.id)
        ..values.deleted = true;
      await qUpdateAccounting.update();
      createHistory(currentUserId, "Учет с id $id удален");
      return AppResponse.ok(message: "Успешное удаление учета");
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка удаления учета');
    }
  }

  void createHistory(int userId, String message) async {
    final user = await managedContext.fetchObjectWithID<User>(userId);
    final createHistoryRowQuery = Query<History>(managedContext)
      ..values.dateOfChange = DateTime.now().toString()
      ..values.user = user
      ..values.historyMessage = message;
    createHistoryRowQuery.insert();
  }
}

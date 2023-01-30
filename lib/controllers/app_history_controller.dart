import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:pr_api/model/history.dart';

import '../model/ModelResponse.dart';
import '../utils/AppUtils.dart';
import '../utils/app_response.dart';

class AppHistoryController extends ResourceController {
  AppHistoryController(this.managedContext);

  final ManagedContext managedContext;

  @Operation.get()
  Future<Response> getHistory(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
  ) async {
    try {
      final id = AppUtils.getIdFromHeader(header);

      final qCreateHistory = Query<History>(managedContext)
        ..where((x) => x.user!.id).equalTo(id);

      final List<History> list = await qCreateHistory.fetch();

      if (list.isEmpty) {
        return Response.notFound(
            body: ModelResponse(data: [], message: "История не найдена"));
      }

      return Response.ok(list);
    } catch (e) {
      return AppResponse.serverError(e);
    }
  }
}

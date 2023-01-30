import 'package:conduit/conduit.dart';

import 'user.dart';

class History extends ManagedObject<_History> implements _History {}

class _History {
  @primaryKey
  int? id;
  @Column(nullable: false)
  String? historyMessage;
  @Column(nullable: false)
  String? dateOfChange;

  @Relate(#historyList, isRequired: true, onDelete: DeleteRule.cascade)
  User? user;
}

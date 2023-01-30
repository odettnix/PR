import 'package:conduit/conduit.dart';
import 'package:pr_api/model/post.dart';

class Author extends ManagedObject<_Author> implements _Author {}

class _Author {
  @primaryKey
  int? id;

  ManagedSet<Post>? postList;
}

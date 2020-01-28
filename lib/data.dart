import 'package:built_value/built_value.dart';

part 'data.g.dart';

/// Base class for any sharable data (document, push messsage)
///
///
@BuiltValue(instantiable: false)
abstract class Data extends Object {}

/// Base class for any data stored on **firestore document**.
@BuiltValue(instantiable: false)
abstract class DocData extends Data {}

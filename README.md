# typed_firestore

Typed firestore entity.

## Usage



```dart

abstract class Car extends DocData implements Built<Car, CarBuilder> {
  static Serializer<Car> get serializer => _$carSerializer;

  String get title;

  @nullable
  String get nullableField;

  Car._();

  factory Car([updates(CarBuilder b)]) = _$Car;
}

@SerializersFor(const [
  Car,
])
Serializers serializers = _$serializers;


final firestore = new TypedFirestore(
  Firestore.instance,
  (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build(),
);

final CollRef<Car> cars = firestore.collection<Car>('cars');


```

import 'dart:async';

import 'package:built_value/serializer.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:quiver/core.dart';

import 'data.dart';

export 'data.dart';

class TypedFirestore {
  final fs.Firestore _inner;
  final Serializers _serializers;

  TypedFirestore(this._inner, this._serializers);

  /// Gets a CollectionReference for the specified Firestore path.
  CollRef<D> collection<D extends DocData>(String path) {
    return CollRef._(this, _inner.collection(path));
  }

  /// Gets a DocumentReference for the specified Firestore path.
  DocRef<D> doc<D extends DocData>(String path) {
    return DocRef._(this, _inner.document(path));
  }
}

/// [DocumentReference]
class DocRef<D extends DocData> {
  const DocRef._(this._firestore, this.raw)
      : assert(_firestore != null),
        assert(raw != null);

  final TypedFirestore _firestore;
  final fs.DocumentReference raw;

  /// This document's given or generated ID in the collection.
  String get id => raw.documentID;

  /// Slash-delimited path representing the database location of this query.
  String get path => raw.path;

  ///	Returns the reference of a collection contained inside of this document.
  CollRef<T> collection<T extends DocData>(String path) =>
      CollRef._(_firestore, raw.collection(path));

  /// Returns the reference of a collection contained inside of this document.
  Future<void> delete() => raw.delete();

  /// Reads the document referenced by this DocumentReference
  ///
  /// If no document exists, the read will return null.
  Future<DocSnapshot<D>> get() {
    return raw.get().then(
          (ds) => DocSnapshot<D>._from(
                _firestore,
                this,
                ds.data,
              ),
        );
  }

  /// Writes to the document referred to by this DocumentReference.
  ///
  /// If the document does not yet exist, it will be created.
  ///
  /// If merge is true, the provided data will be merged into an existing document instead of overwriting.
  Future<void> setData(D data, {bool merge: false}) {
    return raw.setData(
      _firestore._serializers.serialize(data, specifiedType: FullType(D))
          as Map<String, dynamic>,
      merge: merge,
    );
  }

  Stream<DocSnapshot<D>> snapshots() {
    return raw
        .snapshots()
        .map((ds) => DocSnapshot<D>._from(_firestore, this, ds.data));
  }

  /// Updates fields in the document referred to by this DocumentReference.
  ///
  /// If no document exists yet, the update will fail.
  Future<void> updateData(D data) {
    return raw.updateData(
      _firestore._serializers.serialize(data, specifiedType: FullType(D))
          as Map<String, dynamic>,
    );
  }

  @override
  int get hashCode => hash2(_firestore, raw);

  @override
  bool operator ==(other) =>
      other is DocRef<D> && _firestore == other._firestore && raw == other.raw;
}

/// [DocumentSnapshot]
class DocSnapshot<D extends DocData> {
  DocSnapshot(this.ref, this.data)
      : assert(ref != null),
        assert(data != null);

  DocSnapshot._from(
      TypedFirestore firestore, DocRef<D> ref, Map<String, dynamic> data)
      : this(
            ref,
            firestore._serializers.deserialize(data, specifiedType: FullType(D))
                as D);

  /// The reference that produced this snapshot
  final DocRef<D> ref;

  DocSnapshot._fromSnapshot(TypedFirestore firestore, fs.DocumentSnapshot ds)
      : this._from(firestore, DocRef._(firestore, ds.reference), ds.data);

  /// Contains all the data of this snapshot
  final D data;

  /// Returns the ID of the snapshot's document
  String get id => ref.id;

  /// Returns `true` if the document exists.
  bool get exists => data != null;
}

/// [QuerySnapshot]
class TypedQuerySnapshot<D extends DocData> {
  final List<fs.DocumentChange> docChanges;
  final List<DocSnapshot<D>> docs;

  const TypedQuerySnapshot(this.docChanges, this.docs);
}

/// [CollectionReference]
class CollRef<D extends DocData> extends TypedQuery<D> {
  final fs.CollectionReference _ref;

  const CollRef._(TypedFirestore firestore, this._ref)
      : assert(_ref != null),
        super(firestore, _ref);

  /// ID of the referenced collection.
  String get id => _ref.id;

  /// A string containing the slash-separated path to this CollectionReference (relative to the root of the database).
  String get path => _ref.path;

  /// For subcollections, parent returns the containing DocumentReference.
  ///
  /// For root collections, null is returned.
  CollRef parent<T>() {
    final p = _ref.parent();
    if (p == null) return null;
    return CollRef._(_firestore, p);
  }

  /// Returns a DocumentReference with the provided path.
  ///
  /// If no path is provided, an auto-generated ID is used.
  ///
  /// The unique key generated is prefixed with a client-generated timestamp so that the resulting list will be chronologically-sorted.
  DocRef<D> doc([String path]) => DocRef._(_firestore, _ref.document(path));

  /// Returns a DocumentReference with an auto-generated ID, after populating it with provided data.
  ///
  /// The unique key generated is prefixed with a client-generated timestamp so that the resulting list will be chronologically-sorted.
  Future<DocRef<D>> add(D data) async {
    final DocRef<D> newDocument = doc();
    await newDocument.setData(data);
    return newDocument;
  }
}

class TypedQuery<D extends DocData> {
  final TypedFirestore _firestore;
  final fs.Query _inner;

  const TypedQuery(this._firestore, this._inner)
      : assert(_firestore != null),
        assert(_inner != null);

  /// Obtains a CollectionReference corresponding to this query's location.
  CollRef<D> reference() => CollRef._(_firestore, _inner.reference());

  TypedFirestore get firestore => _firestore;

  /// Creates and returns a new Query with additional filter on specified field.
  ///
  /// Only documents satisfying provided condition are included in the result set.
  TypedQuery<D> where(
    String field, {
    dynamic isEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    bool isNull,
  }) {
    return TypedQuery(
        _firestore,
        _inner.where(
          field,
          isEqualTo: isEqualTo,
          isLessThan: isLessThan,
          isLessThanOrEqualTo: isLessThanOrEqualTo,
          isGreaterThan: isGreaterThan,
          isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
          isNull: isNull,
        ));
  }

  ///
  /// //
  // TODO: TypedQuery<D> startAfter
  // TODO: TypedQuery<D> startAt
  // TODO: TypedQuery<D> endAt
  // TODO: TypedQuery<D> endBefore

  /// Fetch the documents for this query
  ///
  Future<TypedQuerySnapshot<D>> getDocs() async {
    final qs = await _inner.getDocuments();

    return TypedQuerySnapshot(
      qs.documentChanges,
      qs.documents
          .map((ds) => DocSnapshot<D>._fromSnapshot(_firestore, ds))
          .toList(growable: false),
    );
  }

  /// Notifies of query results at this location
  Stream<TypedQuerySnapshot<D>> snapshots() {
    return _inner.snapshots().map((qs) {
      return TypedQuerySnapshot(
        qs.documentChanges,
        qs.documents
            .map((ds) => DocSnapshot<D>._fromSnapshot(_firestore, ds))
            .toList(growable: false),
      );
    });
  }

  /// Creates and returns a new Query that's additionally limited to only return up to the specified number of documents.
  TypedQuery<D> limit(int length) =>
      TypedQuery(_firestore, _inner.limit(length));

  /// Creates and returns a new Query that's additionally sorted by the specified field.
  TypedQuery<D> orderBy(
    String field, {
    bool descending: false,
  }) =>
      TypedQuery(
          _firestore,
          _inner.orderBy(
            field,
            descending: descending,
          ));
}

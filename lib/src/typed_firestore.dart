import 'dart:async';

import 'package:built_value/serializer.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quiver/core.dart';

import 'data.dart';

class TypedFirestore {
  final fs.Firestore _inner;
  final Serializers _serializers;

  TypedFirestore(this._inner, this._serializers);

  /// Gets a CollectionReference for the specified Firestore path.
  CollRef<D> collection<D extends DocData>(String path) {
    return CollRef._(this, _inner.collection(path));
  }

  /// Gets a Query for the specified collection group.
  TypedQuery<D> collectionGroup<D extends DocData>(String path) {
    return TypedQuery(this, _inner.collectionGroup(path));
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
  Future<DocSnapshot<D>> get({
    Source source: Source.serverAndCache,
  }) async {
    return raw.get(source: source).then(
          (ds) => DocSnapshot<D>._fromSnapshot(_firestore, ds),
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

  Stream<DocSnapshot<D>> snapshots({
    bool includeMetadataChanges = false,
  }) {
    return raw
        .snapshots(
          includeMetadataChanges: includeMetadataChanges,
        )
        .map((ds) => DocSnapshot<D>._fromSnapshot(_firestore, ds));
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
  DocSnapshot(this.ref, this.data, this.metadata) : assert(ref != null);

  DocSnapshot._from(TypedFirestore firestore, DocRef<D> ref,
      Map<String, dynamic> data, fs.SnapshotMetadata metadata)
      : this(
          ref,
          data == null
              ? null
              : firestore._serializers
                  .deserialize(data, specifiedType: FullType(D)) as D,
          metadata,
        );

  /// The reference that produced this snapshot
  final DocRef<D> ref;

  DocSnapshot._fromSnapshot(TypedFirestore firestore, fs.DocumentSnapshot ds)
      : this._from(
          firestore,
          DocRef._(firestore, ds.reference),
          ds.data,
          ds.metadata,
        );

  /// Contains all the data of this snapshot.
  final D data;

  /// Metadata about a snapshot, describing the state of the snapshot.
  final fs.SnapshotMetadata metadata;

  /// Returns the ID of the snapshot's document
  String get id => ref.id;

  /// Returns `true` if the document exists.
  bool get exists => data != null;
}

/// [QuerySnapshot]
class TypedQuerySnapshot<D extends DocData> {
  final List<fs.DocumentChange> docChanges;
  final List<DocSnapshot<D>> docs;
  final fs.SnapshotMetadata metadata;

  const TypedQuerySnapshot(this.docChanges, this.docs, this.metadata);
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

  /// For subcollections, parent returns the containing [DocumentReference].
  ///
  /// For root collections, null is returned.
  DocRef<P> parent<P extends DocData>() {
    final p = _ref.parent();
    if (p == null) return null;
    return DocRef._(_firestore, p);
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
    dynamic arrayContains,
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
          arrayContains: arrayContains,
          isNull: isNull,
        ));
  }

  /// Takes a list of [values], creates and returns a new [Query] that starts
  /// after the provided fields relative to the order of the query.
  ///
  /// The [values] must be in order of [orderBy] filters.
  ///
  /// Cannot be used in combination with [startAt], [startAfterDocument], or
  /// [startAtDocument].
  TypedQuery<D> startAfter(List<dynamic> values) {
    return TypedQuery(_firestore, _inner.startAfter(values));
  }

  /// Takes a list of [values], creates and returns a new [Query] that starts at
  /// the provided fields relative to the order of the query.
  ///
  /// The [values] must be in order of [orderBy] filters.
  ///
  /// Cannot be used in combination with [startAfter], [startAfterDocument],
  /// or [startAtDocument].
  TypedQuery<D> startAt(List<dynamic> values) {
    return TypedQuery(_firestore, _inner.startAt(values));
  }

  // TODO: TypedQuery<D> endAtDocument

  /// Takes a list of [values], creates and returns a new [Query] that ends at the
  /// provided fields relative to the order of the query.
  ///
  /// The [values] must be in order of [orderBy] filters.
  ///
  /// Cannot be used in combination with [endBefore], [endBeforeDocument], or
  /// [endAtDocument].
  TypedQuery<D> endAt(List<dynamic> values) {
    return TypedQuery(_firestore, _inner.endAt(values));
  }

  /// Takes a list of [values], creates and returns a new [Query] that ends before
  /// the provided fields relative to the order of the query.
  ///
  /// The [values] must be in order of [orderBy] filters.
  ///
  /// Cannot be used in combination with [endAt], [endBeforeDocument], or
  /// [endBeforeDocument]
  TypedQuery<D> endBefore(List<dynamic> values) {
    return TypedQuery(_firestore, _inner.endBefore(values));
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

  /// `mapper` is called **after** fetching documents.
  TypedQuery<D> mapList(Mapper<List<DocSnapshot<D>>> mapper) {
    return _MapList(
      firestore: _firestore,
      inner: _inner,
      mapper: mapper,
    );
  }

  /// `mapper` is called **after** fetching documents.
  TypedQuery<D> map(Mapper<D> mapper) {
    return _MappedQuery(
      firestore: _firestore,
      inner: _inner,
      mapper: mapper,
    );
  }

  /// Fetch the documents for this query
  ///
  Future<TypedQuerySnapshot<D>> getDocs({
    Source source = fs.Source.serverAndCache,
  }) async {
    final qs = await _inner.getDocuments(source: source);

    return TypedQuerySnapshot(
      qs.documentChanges,
      qs.documents
          .map((ds) => DocSnapshot<D>._fromSnapshot(_firestore, ds))
          .toList(growable: false),
      qs.metadata,
    );
  }

  /// Notifies of query results at this location
  Stream<TypedQuerySnapshot<D>> snapshots({
    bool includeMetadataChanges = false,
  }) {
    return _inner
        .snapshots(
      includeMetadataChanges: includeMetadataChanges,
    )
        .map((qs) {
      return TypedQuerySnapshot(
        qs.documentChanges,
        qs.documents
            .map((ds) => DocSnapshot<D>._fromSnapshot(_firestore, ds))
            .toList(growable: false),
        qs.metadata,
      );
    });
  }
}

typedef FutureOr<T> Mapper<T>(T data);

class _MappedQuery<D extends DocData> extends TypedQuery<D> {
  final Mapper<D> mapper;

  _MappedQuery({
    @required TypedFirestore firestore,
    @required fs.Query inner,
    @required this.mapper,
  })  : assert(firestore != null),
        assert(inner != null),
        assert(mapper != null),
        super(firestore, inner);

  /// Fetch the documents for this query
  ///
  Future<TypedQuerySnapshot<D>> getDocs({
    Source source = fs.Source.serverAndCache,
  }) async {
    final qs = await _inner.getDocuments(source: source);

    final docs = await Future.wait(
      qs.documents.map((ds) async {
        final ss = DocSnapshot<D>._fromSnapshot(_firestore, ds);
        return DocSnapshot(ss.ref, await mapper(ss.data), ss.metadata);
      }).toList(growable: false),
    );

    return TypedQuerySnapshot(
      qs.documentChanges,
      docs,
      qs.metadata,
    );
  }

  /// Notifies of query results at this location
  Stream<TypedQuerySnapshot<D>> snapshots({
    bool includeMetadataChanges = false,
  }) async* {
    await for (final qs in _inner.snapshots(
      includeMetadataChanges: includeMetadataChanges,
    )) {
      final docs = await Future.wait(
        qs.documents.map((ds) async {
          final ss = DocSnapshot<D>._fromSnapshot(_firestore, ds);
          return DocSnapshot(ss.ref, await mapper(ss.data), ds.metadata);
        }).toList(growable: false),
      );

      yield TypedQuerySnapshot(
        qs.documentChanges,
        docs,
        qs.metadata,
      );
    }
  }
}

class _MapList<D extends DocData> extends TypedQuery<D> {
  final Mapper<List<DocSnapshot<D>>> mapper;

  _MapList({
    @required TypedFirestore firestore,
    @required fs.Query inner,
    @required this.mapper,
  })  : assert(firestore != null),
        assert(inner != null),
        assert(mapper != null),
        super(firestore, inner);

  /// Fetch the documents for this query
  ///
  Future<TypedQuerySnapshot<D>> getDocs({
    Source source = fs.Source.serverAndCache,
  }) async {
    final qs = await _inner.getDocuments(source: source);

    return TypedQuerySnapshot(
      qs.documentChanges,
      await mapper(
        qs.documents.map((ds) {
          return DocSnapshot<D>._fromSnapshot(_firestore, ds);
        }).toList(
          growable: false,
        ),
      ),
      qs.metadata,
    );
  }

  /// Notifies of query results at this location
  Stream<TypedQuerySnapshot<D>> snapshots({
    bool includeMetadataChanges = false,
  }) async* {
    await for (final qs in _inner.snapshots(
      includeMetadataChanges: includeMetadataChanges,
    )) {
      yield TypedQuerySnapshot(
        qs.documentChanges,
        await mapper(
          qs.documents.map((ds) {
            return DocSnapshot<D>._fromSnapshot(_firestore, ds);
          }).toList(
            growable: false,
          ),
        ),
        qs.metadata,
      );
    }
  }
}

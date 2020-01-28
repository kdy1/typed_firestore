## [0.4.0] - 2020-01-28

 - Updated cloud_firestore
 - Export `Data` and `DocData` from separate lib to support sharing models with server. 


## [0.3.4] - 2019-08-01

 - All types now implements hashCode and `==`.

## [0.3.3] - 2019-08-27

 - `.mapList` can now changes type.

## [0.3.2] - 2019-08-09

 - Added `DocRef<T>.parent`

## [0.3.1] - 2019-08-08

 - Added `collectionGroup`


## [0.3.0] - 2019-08-04

 -  `TypedQuery<D>`
   - `.getDocs()`: Added `source`.
   - `.snapshots()`: Added `includeMetadataChanges`.
    
 - `DocRef<D>`
   - `.get()`: Added `source`.
   - `.snapshots()`: Added `includeMetadataChanges`.
 
## [0.2.2] - 2019-07-31

 - `TypedQuery.map`
 - `TypedQuery.mapList`
 
## [0.2.1] - 2019-07-31

 - Array-contains query

## [0.2.0+1] - 2019-07-10

 - Fixed a bug.

## [0.2.0] - 2019-07-10

 - Bumped version of cloud_firestore.

## [0.1.1] - 2019-05-16

startAt, startBefore, endAt, endBefore


## [0.0.3] - 2019-03-24

Support non-existent docs. 


## [0.0.1] - 2018-09-24

* First release.

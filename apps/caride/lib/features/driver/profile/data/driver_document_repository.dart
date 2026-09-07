import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:caride/core/driver/models/driver_document.dart';
import 'package:caride/core/driver/verification/driver_verification_config.dart';

class DriverDocumentRepository {
  DriverDocumentRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? _safeStorageInstance();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static FirebaseStorage _safeStorageInstance() {
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      try {
        return FirebaseStorage.instanceFor(bucket: 'gs://caride-app.firebasestorage.app');
      } catch (_) {
        return FirebaseStorage.instanceFor(bucket: 'caride-app.firebasestorage.app');
      }
    }
  }

  static const List<String> documentTypes = standardDriverDocumentTypes;
  static const List<String> courierDocumentTypes = courierDriverDocumentTypes;

  CollectionReference<Map<String, dynamic>> _docsCol(String uid) =>
      _firestore.collection('drivers').doc(uid).collection('documents');

  Future<String> uploadDocument({
    required String uid,
    required String documentType,
    required File file,
  }) async {
    final ext = file.path.split('.').last;
    final storageRef = _storage
        .ref()
        .child('driver_documents/$uid/$documentType.$ext');

    final uploadTask = await storageRef.putFile(file);
    final fileUrl = await uploadTask.ref.getDownloadURL();

    await saveDocumentMetadata(
      uid: uid,
      documentType: documentType,
      fileUrl: fileUrl,
      status: 'pending',
    );

    return fileUrl;
  }

  Future<void> saveDocumentMetadata({
    required String uid,
    required String documentType,
    required String fileUrl,
    required String status,
  }) async {
    final batch = _firestore.batch();
    
    // 1. Save document metadata
    final docRef = _docsCol(uid).doc(documentType);
    batch.set(docRef, {
      'documentType': documentType,
      'fileUrl': fileUrl,
      'status': status,
      'rejectionReason': null,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    // 2. Set driver's root approval status to pending for verification queue testing
    final driverRef = _firestore.collection('drivers').doc(uid);
    batch.update(driverRef, {
      'approvalStatus': 'pending',
    });

    await batch.commit();
  }

  Future<List<DriverDocument>> getDocuments(String uid) async {
    final snap = await _docsCol(uid).get();
    return snap.docs.map(DriverDocument.fromDoc).toList();
  }

  Stream<List<DriverDocument>> streamDocuments(String uid) {
    return _docsCol(uid).snapshots().map(
      (snap) => snap.docs.map(DriverDocument.fromDoc).toList(),
    );
  }

  Future<DriverDocument?> getDocument(String uid, String documentType) async {
    final doc = await _docsCol(uid).doc(documentType).get();
    if (!doc.exists) return null;
    return DriverDocument.fromDoc(doc);
  }

  Future<void> saveGuarantorInfo({
    required String uid,
    required String fullName,
    required String phone,
    required String address,
    required String relationship,
  }) async {
    final batch = _firestore.batch();

    final docRef = _docsCol(uid).doc('guarantor_info');
    batch.set(docRef, {
      'documentType': 'guarantor_info',
      'fullName': fullName,
      'phone': phone,
      'address': address,
      'relationship': relationship,
      'fileUrl': null,
      'status': 'pending',
      'rejectionReason': null,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    final driverRef = _firestore.collection('drivers').doc(uid);
    batch.set(driverRef, {
      'guarantorName': fullName,
      'guarantorPhone': phone,
      'guarantorAddress': address,
      'guarantorRelationship': relationship,
      'approvalStatus': 'pending',
    }, SetOptions(merge: true));

    await batch.commit();
  }
}

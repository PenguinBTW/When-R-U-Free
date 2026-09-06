import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../config/cloud_config.dart';
import '../../firebase_options.dart';
import '../../models/friend.dart';
import '../../models/lesson.dart';
import '../../models/user_profile.dart';

/// Firestore sync layer. Fully implemented but DORMANT until
/// [DefaultFirebaseOptions.isConfigured] && [kCloudBackendEnabled].
///
/// Schema:
///   users/{uid}              { displayName, friendCode, college, updatedAt }
///   users/{uid}/lessons/{id} { subject, weekday, startMin, endMin, location }
class FirestoreDataStore {
  FirestoreDataStore._();
  static final FirestoreDataStore instance = FirestoreDataStore._();

  bool _ready = false;
  bool get isReady => _ready;

  /// Call once from main(). Returns false (and leaves local mode active)
  /// when keys are blank, Firebase init fails, or the flag is off.
  Future<bool> tryInit() async {
    if (!kCloudBackendEnabled || !DefaultFirebaseOptions.isConfigured) {
      debugPrint('[cloud] disabled — running local-first (keys blank).');
      return false;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Anonymous auth keeps onboarding frictionless; upgrade to full
      // providers later without changing the schema.
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      _ready = true;
      debugPrint('[cloud] Firestore sync enabled.');
      return true;
    } catch (e) {
      debugPrint('[cloud] init failed, staying local: $e');
      _ready = false;
      return false;
    }
  }

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection(kUsersCollection);

  DocumentReference<Map<String, dynamic>>? get _me =>
      uid == null ? null : _users.doc(uid);

  Future<void> pushProfile(UserProfile profile) async {
    if (!_ready || _me == null) return;
    await _me!.set({
      'displayName': profile.displayName,
      'friendCode': profile.friendCode,
      'college': profile.college,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> pushLessons(List<Lesson> lessons) async {
    if (!_ready || _me == null) return;
    final col = _me!.collection(kLessonsSubcollection);
    final existing = await col.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final l in lessons) {
      batch.set(col.doc(l.id), {
        'subject': l.subject,
        'weekday': l.weekday,
        'startMin': l.startMin,
        'endMin': l.endMin,
        'location': l.location,
      });
    }
    await batch.commit();
  }

  Future<List<Lesson>> pullLessons() async {
    if (!_ready || _me == null) return [];
    final snap = await _me!.collection(kLessonsSubcollection).get();
    return snap.docs.map((d) {
      final data = d.data();
      return Lesson(
        id: d.id,
        subject: data['subject'] as String? ?? 'Lesson',
        weekday: (data['weekday'] as num? ?? 1).toInt(),
        startMin: (data['startMin'] as num? ?? 540).toInt(),
        endMin: (data['endMin'] as num? ?? 600).toInt(),
        location: data['location'] as String? ?? '',
      );
    }).toList();
  }

  /// Looks up another user by friend code. Requires a Firestore composite
  /// setup: collectionGroup or a `friendCodes/{code} -> uid` index doc.
  /// Until cloud is on, callers fall back to local demo friends.
  Future<Friend?> lookupByFriendCode(String code) async {
    if (!_ready) return null;
    final q = await _users
        .where('friendCode', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final doc = q.docs.first;
    final data = doc.data();
    final lessonsSnap =
        await doc.reference.collection(kLessonsSubcollection).get();
    return Friend(
      id: doc.id,
      displayName: data['displayName'] as String? ?? 'Friend',
      friendCode: (data['friendCode'] as String? ?? code).toUpperCase(),
      lessons: lessonsSnap.docs
          .map((d) => Lesson.fromJson({...d.data(), 'id': d.id}))
          .toList(),
    );
  }

  Stream<List<Lesson>> watchMyLessons() {
    if (!_ready || _me == null) return const Stream.empty();
    return _me!
        .collection(kLessonsSubcollection)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Lesson.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }
}

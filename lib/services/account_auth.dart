import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/account_identity.dart';

String accountLoginEmail(String username) =>
    '${sha256.convert(utf8.encode(username.trim().toLowerCase()))}@accounts.invalid';

class AccountAuth {
  Future<Map<String, dynamic>?> login(String username, String password) async {
    AccountSession.current = null;
    try {
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      final credential = await auth.signInWithEmailAndPassword(
        email: accountLoginEmail(username),
        password: password,
      );
      final uid = credential.user!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      final data = doc.data();
      if (data == null || data['status'] != 'active') {
        await auth.signOut();
        return null;
      }
      return {...data, 'id': uid};
    } on FirebaseAuthException catch (error) {
      if ([
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'user-disabled',
        'invalid-email',
      ].contains(error.code)) {
        return null;
      }
      rethrow;
    } on FirebaseException catch (error) {
      await FirebaseAuth.instance.signOut();
      // Inactive/deleted accounts cannot read their own profile. Treat them
      // exactly like invalid credentials so login never reveals account state.
      if (error.code == 'permission-denied') return null;
      rethrow;
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      rethrow;
    }
  }

  static Future<void> signOut() async {
    AccountSession.current = null;
    await FirebaseAuth.instance.signOut();
  }
}

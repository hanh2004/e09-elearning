import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/services/tai_khoan/xac_thuc_tai_khoan.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'learner';
}

class _Credential extends Fake implements UserCredential {
  @override
  User get user => _User();
}

class _Auth extends Fake implements FirebaseAuth {
  Object? error;
  var signOuts = 0;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (error != null) throw error!;
    return _Credential();
  }

  @override
  Future<void> signOut() async => signOuts++;
}

void main() {
  const previous = AccountIdentity(id: 'old', role: 'admin');
  tearDown(() => AccountSession.current = null);

  test(
    'clears local identity after auth succeeds but the profile is unreadable',
    () async {
      AccountSession.current = previous;
      final auth = _Auth();
      final db = FakeFirebaseFirestore(
        securityRules: '''
      service cloud.firestore {
        match /databases/{database}/documents {
          match /{document=**} { allow read, write: if false; }
        }
      }
    ''',
      );

      await expectLater(
        AccountAuth(auth: auth, firestore: db).login('learner', 'password'),
      throwsException,
      );

      expect(auth.signOuts, 1);
      expect(AccountSession.current, isNull);
    },
  );

  test('an invalid password preserves the current session', () async {
    AccountSession.current = previous;
    final auth = _Auth()
      ..error = FirebaseAuthException(code: 'invalid-credential');

    expect(
      await AccountAuth(
        auth: auth,
        firestore: FakeFirebaseFirestore(),
      ).login('learner', 'wrong'),
      isNull,
    );

    expect(auth.signOuts, 0);
    expect(AccountSession.current, same(previous));
  });

  test(
    'a blocked profile ends the authenticated login and clears identity',
    () async {
      AccountSession.current = previous;
      final auth = _Auth();
      final db = FakeFirebaseFirestore();
      await db.doc('users/learner').set({'role': 'user', 'status': 'blocked'});

      expect(
        await AccountAuth(
          auth: auth,
          firestore: db,
        ).login('learner', 'password'),
        isNull,
      );

      expect(auth.signOuts, 1);
      expect(AccountSession.current, isNull);
    },
  );
}

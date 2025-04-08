import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';

class UserProvider with ChangeNotifier {
  User? _user;
  User? get user => _user;

  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;
  // 🔽 同意ポリシーフラグ（AuthGateでダイアログ表示用）
  bool _shouldShowPolicyDialog = false;
  bool get shouldShowPolicyDialog => _shouldShowPolicyDialog;

  UserProvider() {
    _initialize(); // ✅ コンストラクタで呼ぶことで自動で初期化
  }

  void _initialize() {
    _auth.authStateChanges().listen((user) async {
      _user = user;
      if (_user != null) {
        await _checkPolicyAgreement();
      }
      _isInitializing = false;
      notifyListeners();
    });
  }

  Future<void> _checkPolicyAgreement() async {
    final uid = _user!.uid;

    final latestPolicyDoc =
        await FirebaseFirestore.instance
            .collection('appMeta')
            .doc('policyVersions')
            .get();

    final latestPrivacy = latestPolicyDoc['privacyPolicyVersion'];
    final latestTerms = latestPolicyDoc['termsOfServiceVersion'];

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final agreedPrivacy = userDoc.data()?['agreedPrivacyPolicyVersion'];
    final agreedTerms = userDoc.data()?['agreedTermsOfServiceVersion'];

    print("最新バージョン: プライバシー: $latestPrivacy, 利用規約: $latestTerms");
    print("同意バージョン: プライバシー: $agreedPrivacy, 利用規約: $agreedTerms");

    final needsConsent =
        agreedPrivacy != latestPrivacy || agreedTerms != latestTerms;

    // 🔵 ログアウト処理を削除、同意フラグのみを有効化
    _shouldShowPolicyDialog = needsConsent;
    print("同意ポリシーダイアログの表示フラグ: $_shouldShowPolicyDialog");

    notifyListeners();
  }

  Future<void> agreeLatestPolicy() async {
    if (_user == null) return;

    final latestPolicyDoc =
        await FirebaseFirestore.instance
            .collection('appMeta')
            .doc('policyVersions')
            .get();

    final latestPrivacy = latestPolicyDoc['privacyPolicyVersion'];
    final latestTerms = latestPolicyDoc['termsOfServiceVersion'];

    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
      'agreedPrivacyPolicyVersion': latestPrivacy,
      'agreedTermsOfServiceVersion': latestTerms,
      'policyAgreedAt': FieldValue.serverTimestamp(), // 任意：同意日時
    }, SetOptions(merge: true));

    _shouldShowPolicyDialog = false;
    notifyListeners();
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kDebugMode) {
        print("[DEBUG] Google Sign-In 開始");
      }

      final googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) {
            print("[DEBUG] Google Sign-In タイムアウト");
          }
          return null;
        },
      );

      if (googleUser == null) {
        if (kDebugMode) {
          print("[DEBUG] Google Sign-In キャンセルされました");
        }
        return null;
      }

      final googleAuth = await googleUser.authentication.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException("GoogleAuth タイムアウト");
        },
      );

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 10));

      _user = result.user;

      // 🔽 同意バージョンの保存処理を追加
      final latestPolicyDoc =
          await FirebaseFirestore.instance
              .collection('appMeta')
              .doc('policyVersions')
              .get();

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'agreedPrivacyPolicyVersion': latestPolicyDoc['privacyPolicyVersion'],
        'agreedTermsOfServiceVersion': latestPolicyDoc['termsOfServiceVersion'],
      }, SetOptions(merge: true));

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists || !userDoc.data()!.containsKey('lastAnalyzedAt')) {
        await userRef.set({
          'lastAnalyzedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return result;
    } catch (error) {
      if (kDebugMode) {
        print("[DEBUG] Google Sign-In 失敗: $error");
      }
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    _user = null;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.reauthenticateWithCredential(credential);
      await user.delete();
      await _googleSignIn.signOut();

      _user = null;
      notifyListeners();

      return true;
    } catch (e) {
      return false;
    }
  }

  void clearPolicyDialogFlag() {
    _shouldShowPolicyDialog = false;
    notifyListeners();
  }
}

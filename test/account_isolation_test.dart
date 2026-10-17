import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nalaro_seller_center/core/errors/api_exception.dart';
import 'package:nalaro_seller_center/data/repositories/seller_repository.dart';
import 'package:nalaro_seller_center/data/services/firebase_auth_service.dart';
import 'package:nalaro_seller_center/data/services/local_draft_service.dart';
import 'package:nalaro_seller_center/data/services/seller_api_service.dart';
import 'package:nalaro_seller_center/domain/models/seller_models.dart';
import 'package:nalaro_seller_center/ui/state/seller_app_state.dart';

FirebaseSession session({bool expired = false}) => FirebaseSession(
    uid: 'firebase-admin',
    email: 'admin@example.test',
    idToken: 'id-token',
    refreshToken: 'refresh',
    emailVerified: true,
    expiresAt: DateTime.now().add(Duration(hours: expired ? -1 : 1)));
const admin = UserIdentity(
    id: 'internal-admin',
    email: 'admin@example.test',
    verified: true,
    admin: true);

class MemoryDrafts extends LocalDraftService {
  Map<String, dynamic>? saved;
  @override
  Future<void> saveSessionJson(Map<String, dynamic> value) async {
    saved = value;
  }

  @override
  Future<Map<String, dynamic>?> loadSessionJson() async => saved;
  @override
  Future<void> clearSession() async {
    saved = null;
  }

  @override
  Future<String?> loadActiveStoreId(String userId) async => null;
}

class FakeAuth extends FirebaseAuthService {
  Completer<FirebaseSession>? login, refresh;
  FirebaseSession value = session();
  @override
  Future<FirebaseSession> signInWithPassword(
          {required String email, required String password}) async =>
      login == null ? value : login!.future;
  @override
  Future<FirebaseSession> refreshSession(FirebaseSession current) async =>
      refresh == null ? session() : refresh!.future;
}

class FakeAPI extends SellerApiService {
  UserIdentity identity = admin;
  final notifications = <String, Completer<Map<String, dynamic>>>{};
  @override
  Future<UserIdentity?> fetchCurrentUser(String token) async => identity;
  @override
  Future<List<MerchantStore>> fetchStores(String token) async => [];
  @override
  Future<Map<String, dynamic>> workspaceResource(
          {required String bearerToken,
          required String storeId,
          required String resource,
          String method = 'GET',
          Object? body,
          Map<String, String>? query}) async =>
      notifications[storeId]!.future;
}

void main() {
  test('a late login cannot restore a signed-out session', () async {
    final auth = FakeAuth()..login = Completer<FirebaseSession>(),
        drafts = MemoryDrafts();
    final repo = SellerRepository(
        authService: auth, apiService: FakeAPI(), draftService: drafts);
    final pending = repo.signIn(email: admin.email, password: 'test');
    final rejected = expectLater(pending, throwsA(isA<ApiException>()));
    await repo.signOut();
    auth.login!.complete(session());
    await rejected;
    expect(repo.currentUser, isNull);
    expect(repo.currentSession, isNull);
    expect(drafts.saved, isNull);
  });
  test('an expired-token refresh cannot overwrite logout', () async {
    final auth = FakeAuth()
          ..value = session(expired: true)
          ..refresh = Completer<FirebaseSession>(),
        drafts = MemoryDrafts();
    final repo = SellerRepository(
        authService: auth, apiService: FakeAPI(), draftService: drafts);
    await repo.signIn(email: admin.email, password: 'test');
    final pending = repo.fetchStores(),
        rejected = expectLater(pending, throwsA(isA<ApiException>()));
    await repo.signOut();
    auth.refresh!.complete(session());
    await rejected;
    expect(repo.currentUser, isNull);
    expect(drafts.saved, isNull);
  });
  test('backend identity must match the authenticated Firebase email',
      () async {
    final api = FakeAPI()
      ..identity = const UserIdentity(
          id: 'other',
          email: 'seller@example.test',
          verified: true,
          admin: false);
    final repo = SellerRepository(
        authService: FakeAuth(), apiService: api, draftService: MemoryDrafts());
    await expectLater(repo.signIn(email: admin.email, password: 'test'),
        throwsA(isA<ApiException>()));
    expect(repo.currentUser, isNull);
  });
  test('admin without merchant membership enters a separate lifecycle',
      () async {
    final repo = SellerRepository(
        authService: FakeAuth(),
        apiService: FakeAPI(),
        draftService: MemoryDrafts());
    final state = SellerAppState(repository: repo);
    expect(await state.signIn(admin.email, 'test'), isTrue);
    expect(state.lifecycle, AuthLifecycleState.platformAdmin);
    expect(state.activeStore, isNull);
    expect(state.stores, isEmpty);
    state.dispose();
  });
  test('old store notifications never replace the active store cache',
      () async {
    final api = FakeAPI();
    final repo = SellerRepository(
        authService: FakeAuth(), apiService: api, draftService: MemoryDrafts());
    await repo.signIn(email: admin.email, password: 'test');
    api.notifications['a'] = Completer();
    api.notifications['b'] = Completer();
    final a = repo.fetchNotifications('a');
    await Future<void>.delayed(Duration.zero);
    repo.clearNotifications();
    final b = repo.fetchNotifications('b');
    api.notifications['b']!.complete({
      'notifications': [
        {'key': 'b-notification', 'title': 'B', 'route': 'chat'}
      ]
    });
    await b;
    api.notifications['a']!.complete({
      'notifications': [
        {'key': 'a-notification', 'title': 'A', 'route': 'orders'}
      ]
    });
    await a;
    expect(repo.getNotificationsForUser().single.storeId, 'b');
  });
}

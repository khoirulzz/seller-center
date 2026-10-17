import 'package:flutter/foundation.dart';

import '../../core/errors/ns_error_mapper.dart';
import '../../data/repositories/seller_repository.dart';
import '../../domain/models/seller_models.dart';

enum AuthLifecycleState {
  initializing,
  unauthenticated,
  unverifiedEmail,
  needsStoreOnboarding,
  authenticatedReady,
}

/// ViewModel utama (`ChangeNotifier`) yang mengelola siklus hidup sesi,
/// daftar toko, perpindahan `active_store_id`, dan isolasi data lintas toko
/// sesuai `PRD` Bab 5.2 & `flutter-apply-architecture-best-practices.md`.
class SellerAppState extends ChangeNotifier {
  SellerAppState({SellerRepository? repository})
    : _repository = repository ?? SellerRepository();

  final SellerRepository _repository;
  final ValueNotifier<AuthLifecycleState> routing = ValueNotifier(
    AuthLifecycleState.initializing,
  );

  @override
  void notifyListeners() {
    routing.value = lifecycle;
    super.notifyListeners();
  }

  @override
  void dispose() {
    routing.dispose();
    super.dispose();
  }

  AuthLifecycleState _lifecycle = AuthLifecycleState.initializing;
  bool _launchPending = false;
  UserIdentity? _user;
  List<MerchantStore> _stores = const [];
  MerchantStore? _activeStore;
  String? _globalError;
  bool _isBusy = false;
  bool _isOffline = false;
  int _storeDataRevision = 0;
  bool _hasUnsavedFormDraft = false;

  SellerRepository get repository => _repository;
  AuthLifecycleState get lifecycle =>
      _launchPending ? AuthLifecycleState.initializing : _lifecycle;
  UserIdentity? get user => _user;
  List<MerchantStore> get stores => _stores;
  MerchantStore? get activeStore => _activeStore;
  StoreRole get activeRole => _activeStore?.storeRole ?? StoreRole.unknown;
  String? get globalError => _globalError;
  bool get isBusy => _isBusy;
  bool get isOffline => _isOffline;
  int get storeDataRevision => _storeDataRevision;
  bool get hasUnsavedFormDraft => _hasUnsavedFormDraft;

  int get unreadNotificationCount =>
      _repository.getNotificationsForUser().where((n) => !n.isRead).length;

  void setHasUnsavedFormDraft(bool dirty) {
    if (_hasUnsavedFormDraft == dirty) return;
    // This flag is read when leaving a form, not rendered. Notifying the router
    // or ancestors while a form is disposing can rebuild a locked widget tree.
    _hasUnsavedFormDraft = dirty;
  }

  void setOfflineStatus(bool offline) {
    if (_isOffline == offline) return;
    _isOffline = offline;
    notifyListeners();
  }

  Future<void> initializeApp({
    Duration minimumSplashDuration = Duration.zero,
  }) async {
    // Run the brief opening composition and session work concurrently.
    // Slower session restoration does not incur an extra branding delay.
    _launchPending = minimumSplashDuration > Duration.zero;
    final splashReady = _launchPending
        ? Future<void>.delayed(minimumSplashDuration)
        : Future<void>.value();
    _lifecycle = AuthLifecycleState.initializing;
    _globalError = null;
    notifyListeners();

    try {
      final restored = await _repository.restoreSession();
      if (restored == null) {
        _lifecycle = AuthLifecycleState.unauthenticated;
        notifyListeners();
        return;
      }
      _user = restored;
      if (!restored.verified) {
        _lifecycle = AuthLifecycleState.unverifiedEmail;
        notifyListeners();
        return;
      }
      await _loadStoresAndSelectActive(restored.id);
    } catch (e) {
      _globalError = NsErrorMapper.toUserMessage(e);
      _lifecycle = AuthLifecycleState.unauthenticated;
      notifyListeners();
    } finally {
      await splashReady;
      _launchPending = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isBusy = true;
    _globalError = null;
    notifyListeners();

    try {
      final identity = await _repository.signIn(
        email: email,
        password: password,
      );
      _user = identity;
      if (!identity.verified) {
        _lifecycle = AuthLifecycleState.unverifiedEmail;
        return true;
      }
      await _loadStoresAndSelectActive(identity.id);
      return true;
    } catch (e) {
      _globalError = NsErrorMapper.toUserMessage(e);
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> register(String email, String password) async {
    _isBusy = true;
    _globalError = null;
    notifyListeners();

    try {
      final identity = await _repository.register(
        email: email,
        password: password,
      );
      _user = identity;
      _lifecycle = AuthLifecycleState.unverifiedEmail;
      return true;
    } catch (e) {
      _globalError = NsErrorMapper.toUserMessage(e);
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> checkEmailVerified() async {
    _isBusy = true;
    _globalError = null;
    notifyListeners();

    try {
      final updated = await _repository.refreshVerificationStatus();
      if (updated != null && updated.verified) {
        _user = updated;
        await _loadStoresAndSelectActive(updated.id);
        return true;
      }
      _globalError = 'Email belum terverifikasi. Buka tautan pada inbox atau folder spam, lalu periksa kembali.';
      return false;
    } catch (e) {
      _globalError = NsErrorMapper.toUserMessage(e);
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _loadStoresAndSelectActive(String userId) async {
    final storesList = await _repository.fetchStores();
    _stores = storesList;
    if (storesList.isEmpty) {
      _activeStore = null;
      _lifecycle = AuthLifecycleState.needsStoreOnboarding;
      notifyListeners();
      return;
    }

    final savedStoreId = await _repository.drafts.loadActiveStoreId(userId);
    final matched =
        storesList.where((s) => s.id == savedStoreId).firstOrNull ??
        storesList.first;
    _activeStore = matched;
    await _repository.drafts.saveActiveStoreId(userId, matched.id);
    _storeDataRevision++;
    _lifecycle = AuthLifecycleState.authenticatedReady;
    notifyListeners();
  }

  /// Perpindahan toko (`AUTH-06` & `desain.md` Bab 5.2).
  /// Memisahkan cache berdasarkan `store_id` dan memicu penyegaran seluruh tab.
  Future<bool> selectActiveStore(String storeId) async {
    final target = _stores.where((s) => s.id == storeId).firstOrNull;
    if (target == null) return false;
    if (_activeStore?.id == target.id) return true;

    _repository.clearMediaCache();
    _activeStore = target;
    _hasUnsavedFormDraft = false;
    _storeDataRevision++;
    if (_user != null) {
      await _repository.drafts.saveActiveStoreId(_user!.id, target.id);
    }
    notifyListeners();
    return true;
  }

  Future<MerchantStore?> createNewStore({
    required String name,
    required String slug,
    String description = '',
  }) async {
    _isBusy = true;
    _globalError = null;
    notifyListeners();

    try {
      final created = await _repository.createStore(
        name: name,
        slug: slug,
        description: description,
      );
      _stores = await _repository.fetchStores();
      _activeStore =
          _stores.where((s) => s.id == created.id).firstOrNull ?? created;
      if (_user != null) {
        await _repository.drafts.saveActiveStoreId(_user!.id, _activeStore!.id);
      }
      _storeDataRevision++;
      _lifecycle = AuthLifecycleState.authenticatedReady;
      return _activeStore;
    } catch (e) {
      _globalError = NsErrorMapper.toUserMessage(e);
      return null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> refreshStoresMetadata() async {
    try {
      final updated = await _repository.fetchStores();
      _stores = updated;
      if (_activeStore != null) {
        _activeStore =
            updated.where((s) => s.id == _activeStore!.id).firstOrNull ??
            updated.firstOrNull;
      }
      _storeDataRevision++;
      notifyListeners();
    } catch (_) {}
  }

  void notifyStoreDataMutated() {
    _storeDataRevision++;
    notifyListeners();
  }

  void clearGlobalError() {
    if (_globalError == null) return;
    _globalError = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _user = null;
    _stores = const [];
    _activeStore = null;
    _hasUnsavedFormDraft = false;
    _globalError = null;
    _lifecycle = AuthLifecycleState.unauthenticated;
    notifyListeners();
  }
}

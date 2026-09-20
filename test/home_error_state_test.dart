import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/domain/models/cashback_model.dart';
import 'package:waddy_app/features/home/domain/services/home_service_interface.dart';

/// Minimal stub: these tests exercise the failure-tracking state machine only,
/// which never touches the service.
class _StubHomeService implements HomeServiceInterface {
  @override
  Future<List<CashBackModel>> getCashBackOfferList() async => [];
  @override
  Future<CashBackModel?> getCashBackData(double amount) async => null;
  @override
  Future<bool> saveRegistrationSuccessful(bool status) async => true;
  @override
  Future<bool> saveIsRestaurantRegistration(bool status) async => true;
  @override
  bool getRegistrationSuccessful() => false;
  @override
  bool getIsRestaurantRegistration() => false;
}

void main() {
  late HomeController c;
  setUp(() => c = HomeController(homeServiceInterface: _StubHomeService()));

  test('records and clears per section', () {
    expect(c.hasAnyError, isFalse);
    c.recordError(HomeSection.fastest);
    expect(c.hasError(HomeSection.fastest), isTrue);
    expect(
      c.hasError(HomeSection.grocery),
      isFalse,
      reason: 'one failure must not mark other sections',
    );
    expect(c.hasAnyError, isTrue);

    c.clearError(HomeSection.fastest);
    expect(c.hasError(HomeSection.fastest), isFalse);
    expect(c.hasAnyError, isFalse);
  });

  test('partial failure leaves healthy sections clean', () {
    c.recordError(HomeSection.grocery);
    c.recordError(HomeSection.offers);
    expect(c.failedSections.length, 2);
    expect(c.hasError(HomeSection.fastest), isFalse);
    expect(c.hasError(HomeSection.recommended), isFalse);
  });

  test('clearAllErrors empties the set', () {
    c.recordError(HomeSection.fastest);
    c.recordError(HomeSection.grocery);
    c.clearAllErrors();
    expect(c.hasAnyError, isFalse);
  });

  test('recording the same section twice is idempotent', () {
    c.recordError(HomeSection.offers);
    c.recordError(HomeSection.offers);
    expect(c.failedSections.length, 1);
  });

  test(
    'failedSections is unmodifiable (state cannot be mutated from outside)',
    () {
      c.recordError(HomeSection.zone);
      expect(() => c.failedSections.add('x'), throwsUnsupportedError);
    },
  );
}

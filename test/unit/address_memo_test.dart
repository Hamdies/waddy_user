import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/util/app_constants.dart';

/// The saved address is read 93 times, mostly inside `build`, and each read used
/// to run a full jsonDecode + AddressModel.fromJson. The memo that fixes that
/// has exactly one way to be dangerous — serving a stale address after someone
/// else changed the stored value — so that is what these check. A wrong answer
/// here is a delivery to the wrong zone, not a slow frame.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String encoded({
    required String address,
    List<int> zoneIds = const <int>[1],
  }) {
    return jsonEncode(
      AddressModel(
        address: address,
        latitude: '30.0444',
        longitude: '31.2357',
        zoneIds: zoneIds,
        addressType: 'home',
      ).toJson(),
    );
  }

  Future<void> seed(Map<String, Object> values) async {
    Get.reset();
    SharedPreferences.setMockInitialValues(values);
    Get.put<SharedPreferences>(await SharedPreferences.getInstance());
  }

  tearDown(Get.reset);

  test('no saved address is a normal state, not an error', () async {
    await seed(<String, Object>{});
    expect(AddressHelper.getUserAddressFromSharedPref(), isNull);
  });

  test('an empty stored string reads as no address', () async {
    await seed(<String, Object>{AppConstants.userAddress: ''});
    expect(AddressHelper.getUserAddressFromSharedPref(), isNull);
  });

  test('parses the stored address', () async {
    await seed(<String, Object>{
      AppConstants.userAddress: encoded(address: 'Mostafa Kamel'),
    });
    expect(
      AddressHelper.getUserAddressFromSharedPref()?.address,
      'Mostafa Kamel',
    );
  });

  test(
    'repeat reads return the same instance — the decode is skipped',
    () async {
      await seed(<String, Object>{
        AppConstants.userAddress: encoded(address: 'Mostafa Kamel'),
      });
      final AddressModel? first = AddressHelper.getUserAddressFromSharedPref();
      final AddressModel? second = AddressHelper.getUserAddressFromSharedPref();
      expect(first, isNotNull);
      expect(identical(first, second), isTrue);
    },
  );

  test('a write by someone else invalidates the memo', () async {
    // AuthRepository writes and clears this key directly, without going through
    // AddressHelper. A hand-invalidated cache would keep serving the old
    // address after sign-out or a login hand-off; keying on the stored string
    // means it cannot.
    await seed(<String, Object>{
      AppConstants.userAddress: encoded(address: 'Mostafa Kamel'),
    });
    expect(
      AddressHelper.getUserAddressFromSharedPref()?.address,
      'Mostafa Kamel',
    );

    await Get.find<SharedPreferences>().setString(
      AppConstants.userAddress,
      encoded(address: 'Zamalek'),
    );

    expect(AddressHelper.getUserAddressFromSharedPref()?.address, 'Zamalek');
  });

  test('a direct removal by someone else invalidates the memo', () async {
    await seed(<String, Object>{
      AppConstants.userAddress: encoded(address: 'Mostafa Kamel'),
    });
    AddressHelper.getUserAddressFromSharedPref();

    // Exactly what AuthRepository.clearSharedData does on sign-out.
    await Get.find<SharedPreferences>().remove(AppConstants.userAddress);

    expect(AddressHelper.getUserAddressFromSharedPref(), isNull);
  });

  test('a corrupt stored value reads as no address and does not stick', () async {
    await seed(<String, Object>{AppConstants.userAddress: 'not json at all'});
    expect(AddressHelper.getUserAddressFromSharedPref(), isNull);

    // A failed parse must not poison the memo — a later good write is picked up.
    await Get.find<SharedPreferences>().setString(
      AppConstants.userAddress,
      encoded(address: 'Maadi'),
    );
    expect(AddressHelper.getUserAddressFromSharedPref()?.address, 'Maadi');
  });

  test('clearAddressFromSharedPref drops the memo', () async {
    await seed(<String, Object>{
      AppConstants.userAddress: encoded(address: 'Mostafa Kamel'),
    });
    AddressHelper.getUserAddressFromSharedPref();

    AddressHelper.clearAddressFromSharedPref();

    expect(AddressHelper.getUserAddressFromSharedPref(), isNull);
  });
}

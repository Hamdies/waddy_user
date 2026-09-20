import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class AddressDetailsWidget extends StatelessWidget {
  final AddressModel? addressDetails;
  const AddressDetailsWidget({super.key, required this.addressDetails});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          addressDetails!.address ?? '',
          style: waddyRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 5),

        Wrap(
          children: [
            (addressDetails!.streetNumber != null &&
                    addressDetails!.streetNumber!.isNotEmpty)
                ? Text(
                  '${'street_number'.tr}: ${addressDetails!.streetNumber!}',
                  style: waddyRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
                : const SizedBox(),

            (addressDetails!.house != null && addressDetails!.house!.isNotEmpty)
                ? Text(
                  '${addressDetails!.streetNumber != null ? ', ' : ''}${'house'.tr}: ${addressDetails!.house!}',
                  style: waddyRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
                : const SizedBox(),

            (addressDetails!.floor != null && addressDetails!.floor!.isNotEmpty)
                ? Text(
                  '${(addressDetails!.streetNumber != null || addressDetails!.house != null) ? ', ' : ''}${'floor'.tr}: ${addressDetails!.floor!}',
                  style: waddyRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
                : const SizedBox(),
          ],
        ),
      ],
    );
  }
}

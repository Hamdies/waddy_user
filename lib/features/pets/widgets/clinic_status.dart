import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/pets/domain/models/vet_clinic_model.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';

/// What a clinic's status line says, and in which colour. Shared by the rail
/// chip and the sheet so the two never disagree.
class ClinicStatus {
  final String label;
  final Color dot;
  final Color ink;

  const ClinicStatus(this.label, this.dot, this.ink);

  /// Null when the clinic has no hours on file: no line beats a guess.
  static ClinicStatus? of(VetClinicModel clinic) {
    final bool? open = clinic.isOpenNow;
    if (open == null) return null;
    if (open) {
      final String? close = clinic.closesAt;
      return ClinicStatus(
        close == null
            ? 'clinic_open_now'.tr
            : 'clinic_open_until'.trParams({'time': _time(close)}),
        WaddyColors.mint,
        WaddyColors.primary,
      );
    }
    final String? opens = clinic.closedToday ? null : clinic.opensAt;
    return ClinicStatus(
      opens == null
          ? 'clinic_closed_now'.tr
          : 'clinic_opens_at'.trParams({'time': _time(opens)}),
      WaddyColors.coralDark,
      WaddyColors.coralInk,
    );
  }

  static String _time(String hhmm) {
    try {
      return DateConverter.convertTimeToTime(hhmm);
    } catch (_) {
      return hhmm;
    }
  }
}

/// "600 m" / "1.4 km".
String clinicDistanceLabel(double km) =>
    km < 1
        ? 'distance_m'.trParams({'n': '${(km * 1000).round()}'})
        : 'distance_km'.trParams({'n': km.toStringAsFixed(1)});

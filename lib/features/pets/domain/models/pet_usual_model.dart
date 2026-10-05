import 'package:waddy_app/features/item/domain/models/item_model.dart';

/// "Remind me every N weeks" for one product (`/customer/pets/reminders`).
class PetReminderModel {
  final int id;
  final int itemId;
  final int intervalDays;
  final DateTime? nextAt;

  const PetReminderModel({
    required this.id,
    required this.itemId,
    required this.intervalDays,
    this.nextAt,
  });

  /// The intervals the server accepts, in days.
  static const List<int> intervals = [14, 21, 28, 42];

  static PetReminderModel? fromJson(dynamic json) {
    if (json is! Map) return null;
    final int? id = int.tryParse('${json['id']}');
    final int? itemId = int.tryParse('${json['item_id']}');
    final int? days = int.tryParse('${json['interval_days']}');
    if (id == null || itemId == null || days == null) return null;
    return PetReminderModel(
      id: id,
      itemId: itemId,
      intervalDays: days,
      nextAt: DateTime.tryParse('${json['next_at']}')?.toLocal(),
    );
  }

  int get weeks => intervalDays ~/ 7;
}

/// The hub's "Luna's usual" (`/customer/pets/usual`): the last food the
/// customer got from a pet shop, and their reminder for it.
class PetUsualModel {
  final Item item;
  final int storeId;
  final PetReminderModel? reminder;

  const PetUsualModel({
    required this.item,
    required this.storeId,
    this.reminder,
  });

  static PetUsualModel? fromJson(dynamic json) {
    if (json is! Map || json['item'] is! Map) return null;
    final int? storeId = int.tryParse('${json['store_id']}');
    if (storeId == null) return null;
    return PetUsualModel(
      item: Item.fromJson(Map<String, dynamic>.from(json['item'])),
      storeId: storeId,
      reminder: PetReminderModel.fromJson(json['reminder']),
    );
  }

  PetUsualModel withReminder(PetReminderModel? reminder) =>
      PetUsualModel(item: item, storeId: storeId, reminder: reminder);
}

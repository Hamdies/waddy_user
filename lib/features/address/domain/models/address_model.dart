import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/util/parse.dart';

class AddressModel {
  int? id;
  String? addressType;
  String? contactPersonNumber;
  String? address;
  String? additionalAddress;
  String? latitude;
  String? longitude;
  int? zoneId;
  List<int>? zoneIds;
  String? method;
  String? contactPersonName;
  String? streetNumber;
  String? house;
  String? floor;
  String? deliveryInstructions;

  /// The saved voice directions, served by the backend.
  String? voiceInstructionFullUrl;

  /// A fresh recording on this device, uploaded with the next save. Not part
  /// of [toJson]: the repository sends it as a file.
  String? voiceInstructionPath;

  /// Clears the saved voice directions on update.
  bool removeVoiceInstruction = false;
  List<ZoneData>? zoneData;
  List<int>? areaIds;
  String? email;

  AddressModel({
    this.id,
    this.addressType,
    this.contactPersonNumber,
    this.address,
    this.additionalAddress,
    this.latitude,
    this.longitude,
    this.zoneId,
    this.zoneIds,
    this.method,
    this.contactPersonName,
    this.streetNumber,
    this.house,
    this.floor,
    this.deliveryInstructions,
    this.voiceInstructionFullUrl,
    this.voiceInstructionPath,
    this.removeVoiceInstruction = false,
    this.zoneData,
    this.areaIds,
    this.email,
  });

  AddressModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    addressType = json['address_type'];
    contactPersonNumber = json['contact_person_number'].toString();
    address = json['address'];
    additionalAddress = json['additional_address'];
    latitude = json['latitude'].toString();
    longitude = json['longitude'].toString();
    zoneId =
        (json['zone_id'] != null && json['zone_id'] != 'null')
            ? Parse.strictInt(json['zone_id'], 'zone_id')
            : null;
    zoneIds = json['zone_ids']?.cast<int>();
    method = json['_method'];
    contactPersonName = json['contact_person_name'];
    streetNumber = json['road'];
    house = json['house'];
    floor = json['floor'];
    deliveryInstructions = json['delivery_instructions'];
    voiceInstructionFullUrl = json['voice_instruction_full_url'];
    if (json['zone_data'] != null) {
      zoneData = [];
      json['zone_data'].forEach((v) {
        zoneData!.add(ZoneData.fromJson(v));
      });
    }
    areaIds = json['area_ids']?.cast<int>();
    if (json['contact_person_email'] != null) {
      email = json['contact_person_email'];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['address_type'] = addressType;
    data['contact_person_number'] = contactPersonNumber;
    data['address'] = address;
    data['additional_address'] = additionalAddress;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['zone_id'] = zoneId;
    data['zone_ids'] = zoneIds;
    data['_method'] = method;
    data['contact_person_name'] = contactPersonName;
    data['road'] = streetNumber;
    data['house'] = house;
    data['floor'] = floor;
    data['delivery_instructions'] = deliveryInstructions;
    data['voice_instruction_full_url'] = voiceInstructionFullUrl;
    if (removeVoiceInstruction) data['remove_voice_instruction'] = '1';
    if (zoneData != null) {
      data['zone_data'] = zoneData!.map((v) => v.toJson()).toList();
    }
    data['area_ids'] = areaIds;
    if (email != null) {
      data['contact_person_email'] = email;
    }
    return data;
  }
}

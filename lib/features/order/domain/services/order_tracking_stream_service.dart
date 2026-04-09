import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:waddy_app/util/app_constants.dart';

/// Model for tracking stream data
class TrackingStreamData {
  final int orderId;
  final String status;
  final String? subStatus;
  final DeliveryManLocation? deliveryMan;
  final DateTime timestamp;
  final String? estimatedDeliveryAt;

  TrackingStreamData({
    required this.orderId,
    required this.status,
    this.subStatus,
    this.deliveryMan,
    required this.timestamp,
    this.estimatedDeliveryAt,
  });

  factory TrackingStreamData.fromJson(Map<String, dynamic> json) {
    return TrackingStreamData(
      orderId: json['order_id'],
      status: json['status'],
      subStatus: json['sub_status'],
      deliveryMan:
          json['delivery_man'] != null
              ? DeliveryManLocation.fromJson(json['delivery_man'])
              : null,
      timestamp: DateTime.parse(json['timestamp']),
      estimatedDeliveryAt: json['estimated_delivery_at'],
    );
  }
}

class DeliveryManLocation {
  final int id;
  final double lat;
  final double lng;
  final double heading;
  final double speed;

  DeliveryManLocation({
    required this.id,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.speed,
  });

  factory DeliveryManLocation.fromJson(Map<String, dynamic> json) {
    return DeliveryManLocation(
      id: json['id'] ?? 0,
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0,
      lng: double.tryParse(json['lng']?.toString() ?? '0') ?? 0,
      heading: (json['heading'] ?? 0).toDouble(),
      speed: (json['speed'] ?? 0).toDouble(),
    );
  }
}

/// SSE Streaming service for real-time order tracking
class OrderTrackingStreamService {
  http.Client? _client;
  StreamController<TrackingStreamData>? _controller;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);

  /// Connect to the SSE stream for an order
  Stream<TrackingStreamData> connect({
    required String orderId,
    required String token,
    String? contactNumber,
    String? guestId,
  }) {
    _controller = StreamController<TrackingStreamData>.broadcast(
      onCancel: () => disconnect(),
    );

    _startConnection(orderId, token, contactNumber, guestId);
    return _controller!.stream;
  }

  void _startConnection(
    String orderId,
    String token,
    String? contactNumber,
    String? guestId,
  ) async {
    if (!_isConnected && _reconnectAttempts >= _maxReconnectAttempts) {
      _controller?.addError('Max reconnection attempts reached');
      return;
    }

    _client?.close();
    _client = http.Client();
    _isConnected = true;

    // Build URL with query parameters
    final queryParams = <String, String>{};
    if (contactNumber != null && contactNumber.isNotEmpty) {
      queryParams['contact_number'] = contactNumber;
    }
    if (guestId != null && guestId.isNotEmpty) {
      queryParams['guest_id'] = guestId;
    }

    final queryString =
        queryParams.isNotEmpty
            ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
            : '';

    final url =
        '${AppConstants.baseUrl}/api/v1/orders/$orderId/stream$queryString';

    debugPrint('SSE: Connecting to $url');

    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        debugPrint('SSE: Connection failed with status ${response.statusCode}');
        _handleConnectionError(
          'HTTP ${response.statusCode}',
          orderId,
          token,
          contactNumber,
          guestId,
        );
        return;
      }

      debugPrint('SSE: Connected successfully');
      _reconnectAttempts = 0;

      // Process the stream
      _subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              _processLine(line);
            },
            onError: (error) {
              debugPrint('SSE: Stream error - $error');
              _handleConnectionError(
                error.toString(),
                orderId,
                token,
                contactNumber,
                guestId,
              );
            },
            onDone: () {
              debugPrint('SSE: Stream closed');
              if (_isConnected) {
                _handleConnectionError(
                  'Stream closed',
                  orderId,
                  token,
                  contactNumber,
                  guestId,
                );
              }
            },
            cancelOnError: false,
          );
    } catch (e) {
      debugPrint('SSE: Connection error - $e');
      _handleConnectionError(
        e.toString(),
        orderId,
        token,
        contactNumber,
        guestId,
      );
    }
  }

  void _processLine(String line) {
    if (line.isEmpty) return;

    if (line.startsWith('data: ')) {
      final jsonStr = line.substring(6).trim();
      if (jsonStr.isEmpty) return;

      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final trackingData = TrackingStreamData.fromJson(data);
        _controller?.add(trackingData);
        debugPrint(
          'SSE: Received update - status: ${trackingData.status}, sub: ${trackingData.subStatus}',
        );
      } catch (e) {
        debugPrint('SSE: Failed to parse data - $e');
      }
    }
  }

  void _handleConnectionError(
    String error,
    String orderId,
    String token,
    String? contactNumber,
    String? guestId,
  ) {
    if (!_isConnected) return;

    _reconnectAttempts++;
    debugPrint(
      'SSE: Reconnect attempt $_reconnectAttempts of $_maxReconnectAttempts',
    );

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _controller?.addError(
        'Connection failed after $_maxReconnectAttempts attempts',
      );
      disconnect();
      return;
    }

    // Attempt reconnection after delay
    Future.delayed(_reconnectDelay, () {
      if (_isConnected) {
        _startConnection(orderId, token, contactNumber, guestId);
      }
    });
  }

  /// Disconnect from the SSE stream
  void disconnect() {
    debugPrint('SSE: Disconnecting');
    _isConnected = false;
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _controller?.close();
    _controller = null;
    _reconnectAttempts = 0;
  }

  /// Check if currently connected
  bool get isConnected => _isConnected;
}

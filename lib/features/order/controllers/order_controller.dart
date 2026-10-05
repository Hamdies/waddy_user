import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waddy_app/common/models/response_model.dart';
import 'package:waddy_app/features/order/domain/models/order_cancellation_body.dart';
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/services/order_service_interface.dart';

class OrderController extends GetxController implements GetxService {
  final OrderServiceInterface orderServiceInterface;

  OrderController({required this.orderServiceInterface});

  PaginatedOrderModel? _runningOrderModel;
  PaginatedOrderModel? get runningOrderModel => _runningOrderModel;

  PaginatedOrderModel? _historyOrderModel;
  PaginatedOrderModel? get historyOrderModel => _historyOrderModel;

  List<OrderDetailsModel>? _orderDetails;
  List<OrderDetailsModel>? get orderDetails => _orderDetails;

  OrderModel? _trackModel;
  OrderModel? get trackModel => _trackModel;

  ResponseModel? _responseModel;
  ResponseModel? get responseModel => _responseModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _showCancelled = false;
  bool get showCancelled => _showCancelled;

  bool _showBottomSheet = true;
  bool get showBottomSheet => _showBottomSheet;

  bool _showOneOrder = true;
  bool get showOneOrder => _showOneOrder;

  List<String?>? _refundReasons;
  List<String?>? get refundReasons => _refundReasons;

  int _selectedReasonIndex = 0;
  int get selectedReasonIndex => _selectedReasonIndex;

  XFile? _refundImage;
  XFile? get refundImage => _refundImage;

  String? _cancelReason;
  String? get cancelReason => _cancelReason;

  List<CancellationData>? _orderCancelReasons;
  List<CancellationData>? get orderCancelReasons => _orderCancelReasons;

  bool _isExpanded = false;
  bool get isExpanded => _isExpanded;

  List<String?>? _supportReasons;
  List<String?>? get supportReasons => _supportReasons;

  final Map<int, List<OrderDetailsModel>> _orderDetailsCache = {};
  Map<int, List<OrderDetailsModel>> get orderDetailsCache => _orderDetailsCache;

  Future<void> fetchOrderDetailsForList(int orderId) async {
    if (_orderDetailsCache.containsKey(orderId)) return;
    List<OrderDetailsModel>? details = await orderServiceInterface
        .getOrderDetails(orderId.toString(), null);
    if (details != null) {
      _orderDetailsCache[orderId] = details;
      update();
    }
  }

  void expandedUpdate(bool status) {
    _isExpanded = status;
    update();
  }

  void setOrderCancelReason(String? reason) {
    _cancelReason = reason;
    update();
  }

  void selectReason(int index, {bool isUpdate = true}) {
    _selectedReasonIndex = index;
    if (isUpdate) {
      update();
    }
  }

  void showOrders() {
    _showOneOrder = !_showOneOrder;
    update();
  }

  void showRunningOrders({bool canUpdate = true}) {
    _showBottomSheet = !_showBottomSheet;
    if (canUpdate) {
      update();
    }
  }

  void pickRefundImage(bool isRemove) async {
    if (isRemove) {
      _refundImage = null;
    } else {
      _refundImage = await ImagePicker().pickImage(source: ImageSource.gallery);
      update();
    }
  }

  Future<void> getOrderCancelReasons() async {
    _orderCancelReasons = null;
    // A failed fetch lands as an empty list rather than null, so the cancel
    // sheet falls back to a typed reason instead of spinning forever.
    _orderCancelReasons = await orderServiceInterface.getCancelReasons() ?? [];
    update();
  }

  Future<void> getRefundReasons() async {
    _selectedReasonIndex = 0;
    _refundReasons = null;
    _refundReasons = await orderServiceInterface.getRefundReasons();
    update();
  }

  Future<void> submitRefundRequest(String note, String? orderId) async {
    _isLoading = true;
    update();
    await orderServiceInterface.submitRefundRequest(
      _selectedReasonIndex,
      _refundReasons,
      note,
      orderId,
      _refundImage,
    );
    _isLoading = false;
    update();
  }

  // Dashboard and home both request page 1 during boot — share one request
  // instead of hitting running-orders twice and overwriting the model. The
  // join window is bounded so a post-checkout or notification-driven refresh
  // never reuses a response that predates the event it reacts to.
  Future<void>? _runningFirstPageInFlight;
  DateTime? _runningFetchStartedAt;

  Future<void> getRunningOrders(
    int offset, {
    bool isUpdate = false,
    bool fromDashboard = false,
  }) {
    if (offset == 1) {
      if (_runningFirstPageInFlight != null &&
          _runningFetchStartedAt != null &&
          DateTime.now().difference(_runningFetchStartedAt!) <
              const Duration(seconds: 2)) {
        return _runningFirstPageInFlight!;
      }
      _runningFetchStartedAt = DateTime.now();
      late final Future<void> fetch;
      fetch = _fetchRunningOrders(
        offset,
        isUpdate: isUpdate,
        fromDashboard: fromDashboard,
      ).whenComplete(() {
        if (identical(_runningFirstPageInFlight, fetch)) {
          _runningFirstPageInFlight = null;
        }
      });
      _runningFirstPageInFlight = fetch;
      return fetch;
    }
    return _fetchRunningOrders(
      offset,
      isUpdate: isUpdate,
      fromDashboard: fromDashboard,
    );
  }

  Future<void> _fetchRunningOrders(
    int offset, {
    bool isUpdate = false,
    bool fromDashboard = false,
  }) async {
    if (offset == 1) {
      _runningOrderModel = null;
      if (isUpdate) {
        update();
      }
    }
    PaginatedOrderModel? orderModel = await orderServiceInterface
        .getRunningOrderList(offset, fromDashboard);
    if (orderModel != null) {
      if (offset == 1) {
        _runningOrderModel = orderModel;
      } else {
        _runningOrderModel!.orders!.addAll(orderModel.orders!);
        _runningOrderModel!.offset = orderModel.offset;
        _runningOrderModel!.totalSize = orderModel.totalSize;
      }
      update();
    }
  }

  /// Re-reads the first page of running orders for a screen that is already
  /// showing them, without the flash a normal reload causes.
  ///
  /// [getRunningOrders] sets the model to null before it fetches, which is right
  /// for a screen that wants its spinner and wrong for the order-tracking bar:
  /// any rebuild during that window reads "no orders" and the bar disappears,
  /// then reappears. This keeps the current model until the answer is in, and
  /// notifies only when something a user can see changed — the same economy
  /// [timerTrackOrder] applies to a single order.
  ///
  /// Yields to any reload already running, and discards its own answer if one
  /// started while it was in flight (that one is newer).
  Future<void> refreshRunningOrdersQuietly() async {
    if (_runningFirstPageInFlight != null) return;
    final PaginatedOrderModel? fresh = await orderServiceInterface
        .getRunningOrderList(1, false);
    if (_runningFirstPageInFlight != null) return;
    final List<OrderModel>? incoming = fresh?.orders;
    if (fresh == null || incoming == null) return;

    final List<OrderModel>? current = _runningOrderModel?.orders;
    if (current == null) {
      _runningOrderModel = fresh;
      update();
      return;
    }

    String sig(OrderModel o) =>
        '${o.id}|${o.orderStatus}|${o.estimatedDeliveryAt}|'
        '${o.deliveryMan?.id}|${o.deliveryMan?.phone}';

    // One page is 10. Within it, the fresh page IS the list; past it the user
    // has scrolled more in, and replacing would throw that away, so only the
    // orders already on screen are updated in place.
    if (current.length <= 10) {
      final bool changed =
          current.map(sig).join(',') != incoming.map(sig).join(',') ||
          _runningOrderModel!.totalSize != fresh.totalSize;
      if (!changed) return;
      _runningOrderModel = fresh;
      update();
      return;
    }

    bool changed = false;
    for (final OrderModel o in incoming) {
      final int i = current.indexWhere((c) => c.id == o.id);
      if (i >= 0 && sig(current[i]) != sig(o)) {
        current[i] = o;
        changed = true;
      }
    }
    if (changed) update();
  }

  Future<void> getHistoryOrders(int offset, {bool isUpdate = false}) async {
    if (offset == 1) {
      _historyOrderModel = null;
      if (isUpdate) {
        update();
      }
    }
    PaginatedOrderModel? orderModel = await orderServiceInterface
        .getHistoryOrderList(offset);
    if (orderModel != null) {
      if (offset == 1) {
        _historyOrderModel = orderModel;
      } else {
        _historyOrderModel!.orders!.addAll(orderModel.orders!);
        _historyOrderModel!.offset = orderModel.offset;
        _historyOrderModel!.totalSize = orderModel.totalSize;
      }
      update();
    }
  }

  Future<void> getSupportReasons() async {
    _supportReasons = await orderServiceInterface.getSupportReasonsList();
    update();
  }

  Future<List<OrderDetailsModel>?> getOrderDetails(String orderID) async {
    _orderDetails = null;
    _isLoading = true;
    _showCancelled = false;

    if (_trackModel == null ||
        (_trackModel!.orderType != 'parcel' &&
            !_trackModel!.prescriptionOrder!)) {
      List<OrderDetailsModel>? detailsList = await orderServiceInterface
          .getOrderDetails(orderID, null);
      _isLoading = false;
      if (detailsList != null) {
        _orderDetails = [];
        _orderDetails!.addAll(detailsList);
      }
    } else {
      _isLoading = false;
      _orderDetails = [];
    }
    update();
    return _orderDetails;
  }

  Future<ResponseModel?> trackOrder(
    String? orderID,
    OrderModel? orderModel,
    bool fromTracking, {
    String? contactNumber,
    bool? fromGuestInput = false,
  }) async {
    _trackModel = null;
    _responseModel = null;
    if (!fromTracking) {
      _orderDetails = null;
    }
    _showCancelled = false;
    if (orderModel == null) {
      _isLoading = true;
      Response response = await orderServiceInterface.trackOrder(
        orderID,
        null,
        contactNumber: contactNumber,
      );
      if (response.statusCode == 200) {
        _trackModel = OrderModel.fromJson(response.body);
        _responseModel = ResponseModel(true, response.body.toString());
      } else {
        _responseModel = ResponseModel(false, response.statusText);
      }
      _isLoading = false;
      update();
    } else {
      _trackModel = orderModel;
      _responseModel = ResponseModel(true, 'Successful');
    }
    return _responseModel;
  }

  /// The guest phone number the open order screen tracks with, so a push can
  /// refresh it without the screen.
  String? _trackContact;

  /// An `order_status` push arrived while the app is open: refresh the order
  /// on screen now instead of at its next 30 s poll.
  Future<void> refreshTrackedOrder(String? orderID) async {
    if (orderID == null || '${_trackModel?.id}' != orderID) return;
    await timerTrackOrder(orderID, contactNumber: _trackContact);
  }

  /// The live map's 10 s poll (LT-05): moves the rider without reloading the
  /// whole order. Returns false when the order's status has moved on, so the
  /// caller reloads the full order.
  ///
  /// Falls back to the full reload when the light endpoint isn't there (a
  /// backend that hasn't been deployed yet) so the map still moves.
  Future<bool> pollRiderLocation(
    String orderID, {
    String? contactNumber,
  }) async {
    final Response response = await orderServiceInterface.getRiderLocation(
      orderID,
      contactNumber: contactNumber,
    );
    final OrderModel? order = _trackModel;
    if (order == null || '${order.id}' != orderID) return true;
    if (response.statusCode != 200 || response.body is! Map) {
      if (response.statusCode == 404) {
        await timerTrackOrder(orderID, contactNumber: contactNumber);
      }
      return true;
    }
    final Map body = response.body as Map;
    if (body['order_status'] != order.orderStatus) return false;
    final DeliveryMan? rider = order.deliveryMan;
    if (rider == null) return false;

    final bool wasStale = rider.locationStale;
    rider.setLocationAge(body['location_age_seconds']);
    final String? lat = body['lat']?.toString();
    final String? lng = body['lng']?.toString();
    if (lat == rider.lat && lng == rider.lng && wasStale == rider.locationStale) {
      return true;
    }
    rider.lat = lat;
    rider.lng = lng;
    update();
    return true;
  }

  Future<ResponseModel?> timerTrackOrder(
    String orderID, {
    String? contactNumber,
  }) async {
    _showCancelled = false;
    _trackContact = contactNumber;

    Response response = await orderServiceInterface.trackOrder(
      orderID,
      null,
      contactNumber: contactNumber,
    );
    if (response.statusCode == 200) {
      final OrderModel next = OrderModel.fromJson(response.body);

      // Only rebuild when something a user can see has actually changed.
      //
      // This fires every 30 seconds while the order screen is open, and it
      // used to call a bare `update()` each time — rebuilding all 15
      // `GetBuilder<OrderController>` trees, including the map, on a tick
      // where the rider had not moved and the status had not changed. On a
      // mid-range device that is a visible stutter every ten seconds for the
      // whole delivery.
      //
      // The rider's position is the field that legitimately changes most
      // often; status and ETA change rarely. Comparing them is far cheaper
      // than the rebuild it avoids.
      final bool changed =
          _trackModel == null ||
          _trackModel!.orderStatus != next.orderStatus ||
          _trackModel!.deliveryMan?.lat != next.deliveryMan?.lat ||
          _trackModel!.deliveryMan?.lng != next.deliveryMan?.lng ||
          _trackModel!.deliveryMan?.locationStale !=
              next.deliveryMan?.locationStale ||
          _trackModel!.deliveryMan?.id != next.deliveryMan?.id ||
          _trackModel!.orderAmount != next.orderAmount;

      _trackModel = next;
      _responseModel = ResponseModel(true, response.body.toString());
      if (changed) update();
    } else {
      _responseModel = ResponseModel(false, response.statusText);
      update();
    }

    return _responseModel;
  }

  Future<bool> cancelOrder(
    int? orderID,
    String? cancelReason, {
    String? guestId,
  }) async {
    _isLoading = true;
    update();
    bool success = await orderServiceInterface.cancelOrder(
      orderID.toString(),
      cancelReason,
      guestId: guestId,
    );
    _isLoading = false;
    Get.back();
    if (success) {
      OrderModel? orderModel = orderServiceInterface.prepareOrderModel(
        _runningOrderModel,
        orderID,
      );
      if (_runningOrderModel != null) {
        _runningOrderModel!.orders!.remove(orderModel);
      }
      _showCancelled = true;
      // Announced here, not in the repository: cancelling is consequential and
      // the order row simply vanishes from the list, which on its own reads as
      // a glitch rather than a confirmation.
      showCustomSnackBar('order_cancelled_successfully'.tr, isError: false);
    }
    update();
    return success;
  }

  Future<bool> switchToCOD(String? orderID, {String? guestId}) async {
    _isLoading = true;
    update();
    bool isSuccess = await orderServiceInterface.switchToCOD(
      orderID,
      guestId: guestId,
    );
    _isLoading = false;
    update();
    return isSuccess;
  }

  bool _isReordering = false;
  bool get isReordering => _isReordering;

  Future<Map<String, dynamic>?> reorder(int orderId) async {
    _isReordering = true;
    update();
    Response response = await orderServiceInterface.reorder(orderId);
    _isReordering = false;
    update();
    if (response.statusCode == 200) {
      return response.body;
    }
    return null;
  }

  void paymentRedirect({
    required String url,
    required bool canRedirect,
    required String? contactNumber,
    required Function onClose,
    required final String? addFundUrl,
    required final String? subscriptionUrl,
    required final String orderID,
    int? storeId,
    required bool createAccount,
    required String guestId,
  }) {
    orderServiceInterface.paymentRedirect(
      url: url,
      canRedirect: canRedirect,
      contactNumber: contactNumber,
      onClose: onClose,
      addFundUrl: addFundUrl,
      subscriptionUrl: subscriptionUrl,
      orderID: orderID,
      storeId: storeId,
      createAccount: createAccount,
      guestId: guestId,
    );
  }
}

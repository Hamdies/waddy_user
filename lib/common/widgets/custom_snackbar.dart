import 'package:waddy_app/common/widgets/waddy_toast.dart';

/// Shows the app toast. See [WaddyToast] for why this no longer goes through
/// `ScaffoldMessenger` or `GetSnackBar`.
///
/// [getXSnackBar] is accepted and ignored: ~80 call sites pass it from when
/// there were two toast implementations, and both now render the same one.
void showCustomSnackBar(
  String? message, {
  bool isError = true,
  bool getXSnackBar = false,
  int? showDuration,
}) {
  if (message == null || message.isEmpty) return;
  WaddyToast.show(
    message,
    isError: isError,
    duration: Duration(seconds: showDuration ?? 2),
  );
}

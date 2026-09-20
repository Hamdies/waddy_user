import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:url_launcher/url_launcher_string.dart';

class FooterView extends StatefulWidget {
  final Widget child;
  final double minHeight;
  final bool visibility;
  const FooterView({
    super.key,
    required this.child,
    this.minHeight = 0.65,
    this.visibility = true,
  });

  @override
  State<FooterView> createState() => _FooterViewState();
}

class _FooterViewState extends State<FooterView> {
  final TextEditingController _newsLetterController = TextEditingController();
  final ConfigModel? _config = Get.find<SplashController>().configModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * widget.minHeight,
          ),
          child: widget.child,
        ),

        const SizedBox.shrink(),
      ],
    );
  }
}

class FooterButton extends StatelessWidget {
  final String title;
  final String route;
  final bool url;
  const FooterButton({
    super.key,
    required this.title,
    required this.route,
    this.url = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      hoverColor: Colors.transparent,
      onTap:
          route.isNotEmpty
              ? () async {
                if (url) {
                  if (await canLaunchUrlString(route)) {
                    launchUrlString(
                      route,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                } else {
                  Get.toNamed(route);
                }
              }
              : null,
      child: Text(
        title,
        style: waddyRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall),
      ),
    );
  }
}

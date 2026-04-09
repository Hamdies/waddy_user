import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class WorkModeToggle extends StatefulWidget {
  const WorkModeToggle({super.key});

  @override
  State<WorkModeToggle> createState() => _WorkModeToggleState();
}

class _WorkModeToggleState extends State<WorkModeToggle> {
  bool _workMode = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: 6,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.laptop_mac_outlined,
              size: 18,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 10),
            Text(
              'WORK MODE',
              style: robotoBold.copyWith(
                fontSize: 12,
                color: Colors.grey.shade700,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            CupertinoSwitch(
              value: _workMode,
              activeTrackColor: Theme.of(context).secondaryHeaderColor,
              onChanged: (val) => setState(() => _workMode = val),
            ),
          ],
        ),
      ),
    );
  }
}

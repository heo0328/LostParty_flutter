import 'package:flutter/material.dart';

class RosterIssueBadge extends StatelessWidget {
  const RosterIssueBadge({
    required this.child,
    required this.visible,
    super.key,
  });
  final Widget child;
  final bool visible;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      if (visible)
        const Positioned(
          left: -8,
          top: -8,
          child: Tooltip(
            message: '참가 캐릭터 확인 필요',
            child: CircleAvatar(
              radius: 7,
              backgroundColor: Colors.red,
              child: Text(
                '!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

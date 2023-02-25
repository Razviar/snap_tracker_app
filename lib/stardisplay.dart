import 'package:flutter/material.dart';

class StarDisplay extends StatelessWidget {
  final int value;
  final void Function(int) onTap;

  const StarDisplay({Key key, this.value = 0, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          child: Icon(
            index < value ? Icons.star : Icons.star_border,
          ),
          onTap: () => onTap.call(index + 1),
        );
      }),
    );
  }
}

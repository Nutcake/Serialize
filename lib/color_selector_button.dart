import "package:flutter/material.dart";

class ColorSelectorButton extends StatelessWidget {
  const ColorSelectorButton({required this.color, this.checkColor, this.selected = false, this.onTap, super.key});

  final Color color;
  final Color? checkColor;
  final bool selected;
  final dynamic Function()? onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(64),
          border: Border.all(
            width: selected ? 2 : 0,
            color: Theme.of(context).colorScheme.primary,
            style: BorderStyle.solid,
          ),
        ),
        child: Material(
          borderRadius: BorderRadius.circular(64),
          color: selected ? color : color.withOpacity(0.4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(64),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.check, color: selected ? checkColor ?? Colors.black : Colors.transparent,),
            ),
          ),
        ),
      );
}

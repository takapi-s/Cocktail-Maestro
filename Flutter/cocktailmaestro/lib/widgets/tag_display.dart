import 'package:flutter/material.dart';

class TagDisplay extends StatelessWidget {
  final List<String> tags;

  const TagDisplay({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            tags.map((tag) {
              final label = tag.replaceFirst(RegExp(r'^\w+_'), '');
              return Container(
                margin: EdgeInsets.only(right: 8),
                child: Chip(label: Text(label, style: TextStyle(fontSize: 12))),
              );
            }).toList(),
      ),
    );
  }
}

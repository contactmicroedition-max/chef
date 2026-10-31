import 'package:flutter/material.dart';

class EmployeeAvatar extends StatelessWidget {
  const EmployeeAvatar({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(name.isNotEmpty ? name.substring(0, 1) : '?'),
    );
  }
}

import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

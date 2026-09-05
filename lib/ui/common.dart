import 'package:flutter/material.dart';
import 'theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Row(children: [
        Expanded(
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    color: ArcColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1))),
        if (trailing != null) trailing!
      ]));
}

class Metric extends StatelessWidget {
  const Metric(
      {super.key, required this.label, required this.value, this.detail});
  final String label;
  final String value;
  final String? detail;
  @override
  Widget build(BuildContext context) => Expanded(
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(color: ArcColors.muted, fontSize: 11)),
            const SizedBox(height: 3),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            if (detail != null)
              Text(detail!,
                  style: const TextStyle(color: ArcColors.muted, fontSize: 11))
          ])));
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ArcColors.muted))
      ]));
}

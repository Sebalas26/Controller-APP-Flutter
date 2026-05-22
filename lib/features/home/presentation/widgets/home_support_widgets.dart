import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.black,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class SummaryItem {
  const SummaryItem(this.label, this.value);

  final String label;
  final String value;
}

class SummaryStrip extends StatelessWidget {
  const SummaryStrip({super.key, required this.items});

  final List<SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => Container(
              width: 155,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blue8,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.gray700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class TabWorkflow extends StatelessWidget {
  const TabWorkflow({super.key, required this.tabs, required this.children});

  final List<String> tabs;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: FormCard(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: AppColors.black,
            unselectedLabelColor: AppColors.gray700,
            indicatorColor: AppColors.black,
            tabs: tabs.map((tab) => Tab(text: tab)).toList(),
          ),
          SizedBox(height: 420, child: TabBarView(children: children)),
        ],
      ),
    );
  }
}

class GuideList extends StatelessWidget {
  const GuideList({super.key, required this.status, required this.icon});

  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        for (final guide in const ['1000000001', '1000000002', '1000000003'])
          GuideTile(guide: guide, status: status, icon: icon),
      ],
    );
  }
}

class GuideTile extends StatelessWidget {
  const GuideTile({
    super.key,
    required this.guide,
    required this.status,
    required this.icon,
    this.onDelete,
  });

  final String guide;
  final String status;
  final IconData icon;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray300),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.black),
          title: Text(
            guide,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(status),
          trailing: onDelete == null
              ? const Icon(Icons.chevron_right)
              : IconButton(
                  tooltip: 'Eliminar',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
        ),
      ),
    );
  }
}

class DashboardTile extends StatelessWidget {
  const DashboardTile({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray300),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.black),
          title: Text(title),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

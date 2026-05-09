import 'package:flutter/material.dart';

class ChatTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedTabIndex;
  final Function(int) onTabSelected;
  final Color primaryColor;

  const ChatTabs({
    Key? key,
    required this.tabs,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: tabs.asMap().entries.map((entry) {
          final isSelected = selectedTabIndex == entry.key;
          return GestureDetector(
            onTap: () => onTabSelected(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class MemoriesSearchFilterWidget extends StatefulWidget {
  final String searchQuery;
  final String activeFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;

  const MemoriesSearchFilterWidget({
    super.key,
    required this.searchQuery,
    required this.activeFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  @override
  State<MemoriesSearchFilterWidget> createState() =>
      _MemoriesSearchFilterWidgetState();
}

class _MemoriesSearchFilterWidgetState
    extends State<MemoriesSearchFilterWidget> {
  late TextEditingController _controller;

  final List<String> _filters = ['All', 'Photos', 'Videos', 'Stories'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantDark.withAlpha(153),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outline, width: 0.8),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(
                Icons.search_rounded,
                size: 18,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: widget.onSearchChanged,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search memories...',
                    hintStyle: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      color: AppTheme.textDisabled,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    widget.onSearchChanged('');
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Filter chips
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isActive = filter == widget.activeFilter;
              return GestureDetector(
                onTap: () => widget.onFilterChanged(filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primaryGreenGlow
                        : AppTheme.surfaceVariantDark.withAlpha(153),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: isActive
                          ? AppTheme.primaryGreen.withAlpha(128)
                          : AppTheme.outline,
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      filter,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive
                            ? AppTheme.primaryGreen
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

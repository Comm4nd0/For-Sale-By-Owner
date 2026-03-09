import 'package:flutter/material.dart';

class EpcRatingBar extends StatelessWidget {
  final String epcRating;

  const EpcRatingBar({super.key, required this.epcRating});

  static const List<String> _labels = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  static const List<Color> _colors = [
    Color(0xFF1A8C37),
    Color(0xFF3DA54A),
    Color(0xFF8DC641),
    Color(0xFFFDD835),
    Color(0xFFF9A825),
    Color(0xFFEF6C00),
    Color(0xFFD32F2F),
  ];

  @override
  Widget build(BuildContext context) {
    if (epcRating.isEmpty) return const SizedBox.shrink();

    final activeIndex = _labels.indexOf(epcRating.toUpperCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(_labels.length, (index) {
            final isActive = index == activeIndex;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < _labels.length - 1 ? 3 : 0,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: isActive ? 32 : 24,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _colors[index]
                        : _colors[index].withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _labels[index],
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: isActive ? 14 : 12,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (activeIndex >= 0) ...[
          const SizedBox(height: 8),
          Text(
            'EPC Rating: ${_labels[activeIndex]}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

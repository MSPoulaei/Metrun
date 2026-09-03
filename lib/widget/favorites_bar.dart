import 'package:flutter/material.dart';
import '../favorites_service.dart';

class FavoritesBar extends StatelessWidget {
  final void Function(String from, String to) onSelectTrip;

  const FavoritesBar({super.key, required this.onSelectTrip});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<FavoriteTrip>>(
      valueListenable: FavoritesService.favoritesNotifier,
      builder: (context, favorites, _) {
        if (favorites.isEmpty) {
          return const SizedBox.shrink();
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4, right: 4),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      'مسیرهای برگزیده',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: favorites.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final fav = favorites[index];
                    return ActionChip(
                      elevation: 1,
                      backgroundColor: Colors.amber.shade50,
                      side: BorderSide(color: Colors.amber.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Text(
                        '${fav.from}  ★  ${fav.to}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => onSelectTrip(fav.from, fav.to),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

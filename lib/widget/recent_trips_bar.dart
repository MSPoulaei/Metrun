import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../recent_trips_service.dart';

class RecentTripsBar extends StatelessWidget {
  final void Function(String from, String to) onSelectTrip;

  const RecentTripsBar({super.key, required this.onSelectTrip});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TripRecord>>(
      valueListenable: RecentTripsService.tripsNotifier,
      builder: (context, trips, _) {
        if (trips.isEmpty) {
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
                    const Icon(Icons.history_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    const Text(
                      'مسیرهای اخیر',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: RecentTripsService.clearTrips,
                      child: const Text(
                        'پاک کردن',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: trips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    return ActionChip(
                      elevation: 0,
                      backgroundColor: AppColors.primaryContainer,
                      side: const BorderSide(color: AppColors.primaryBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Text(
                        '${trip.from}  ←  ${trip.to}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => onSelectTrip(trip.from, trip.to),
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

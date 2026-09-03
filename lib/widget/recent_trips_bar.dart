import 'package:flutter/material.dart';
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
                    Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'مسیرهای اخیر',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: RecentTripsService.clearTrips,
                      child: Text(
                        'پاک کردن',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
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
                      elevation: 1,
                      backgroundColor: Colors.orange.shade50,
                      side: BorderSide(color: Colors.orange.shade200),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Text(
                        '${trip.from}  ←  ${trip.to}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
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

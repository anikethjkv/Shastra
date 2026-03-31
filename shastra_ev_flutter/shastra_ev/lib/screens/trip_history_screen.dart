import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle_data.dart';
import '../theme/app_theme.dart';

class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<VehicleProvider>().trips;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('TRIP HISTORY'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: trips.isEmpty
          ? const Center(
              child: Text(
                'NO TRIPS RECORDED',
                style: TextStyle(
                  fontSize: 12, letterSpacing: 3, color: AppColors.textMuted,
                ),
              ),
            )
          : Column(
              children: [
                // Summary cards
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _SummaryRow(trips: trips),
                ),
                // Trip list
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: trips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _TripCard(trip: trips[i], index: i),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<TripRecord> trips;
  const _SummaryRow({required this.trips});

  @override
  Widget build(BuildContext context) {
    final totalKm = trips.fold(0.0, (s, t) => s + t.distanceKm);
    final totalEnergy = trips.fold(0.0, (s, t) => s + t.energyUsedKwh);
    final avgEff = trips.isEmpty ? 0.0 :
        trips.fold(0.0, (s, t) => s + t.avgEfficiency) / trips.length;

    return Row(
      children: [
        _SumCard('Total Distance', '${totalKm.toStringAsFixed(1)} km', AppColors.cyan),
        const SizedBox(width: 8),
        _SumCard('Energy Used', '${totalEnergy.toStringAsFixed(1)} kWh', AppColors.orange),
        const SizedBox(width: 8),
        _SumCard('Avg Efficiency', '${avgEff.toStringAsFixed(0)}%', AppColors.green),
      ].map((w) => Expanded(child: w)).toList(),
    );
  }
}

class _SumCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SumCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: const TextStyle(fontSize: 9, letterSpacing: 1.5,
              color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
            style: TextStyle(
              fontFamily: 'Rajdhani', fontSize: 18, fontWeight: FontWeight.w700,
              color: color)),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripRecord trip;
  final int index;
  const _TripCard({required this.trip, required this.index});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM · HH:mm');
    final dur = trip.duration;
    final durStr = '${dur.inMinutes}m ${dur.inSeconds % 60}s';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(
                      fontFamily: 'Rajdhani', fontWeight: FontWeight.w700,
                      fontSize: 14, color: AppColors.cyan,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmt.format(trip.startTime),
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Duration: $durStr',
                      style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${trip.distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                  fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Stat('Avg Speed', '${trip.avgSpeedKmh.toStringAsFixed(0)} km/h', AppColors.cyan),
              _Stat('Max Speed', '${trip.maxSpeedKmh.toStringAsFixed(0)} km/h', AppColors.red),
              _Stat('Energy', '${trip.energyUsedKwh.toStringAsFixed(2)} kWh', AppColors.amber),
              _Stat('Efficiency', '${trip.avgEfficiency.toStringAsFixed(0)}%', AppColors.green),
            ],
          ),
          // Efficiency bar
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: trip.avgEfficiency / 100,
              backgroundColor: AppColors.bg3,
              valueColor: AlwaysStoppedAnimation(
                trip.avgEfficiency > 90 ? AppColors.green :
                trip.avgEfficiency > 70 ? AppColors.amber : AppColors.red,
              ),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
          style: const TextStyle(fontSize: 9, color: AppColors.textMuted,
            letterSpacing: 1)),
        Text(value,
          style: TextStyle(
            fontFamily: 'Rajdhani', fontSize: 13, fontWeight: FontWeight.w700,
            color: color)),
      ],
    );
  }
}

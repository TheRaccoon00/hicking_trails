import 'package:flutter/material.dart';
import '../models/trail.dart';
import '../theme/app_theme.dart';
import '../services/gpx_service.dart';
import '../models/weather_day.dart';
import '../l10n/app_localizations.dart';
import '../screens/hiking_mode_screen.dart';

class TrailCard extends StatelessWidget {
  final Trail trail;
  final bool isSelected;
  final bool isFav;
  final bool hideUnloved;
  final Function(String) onToggleFavorite;
  final Function(String) onTap;

  // Data from Parent Cache
  final List<double>? elevationData;
  final bool isElevLoading;
  final List<WeatherDay>? weatherData; // Changed from dynamic to WeatherDay
  final bool isWeatherLoading;

  const TrailCard({
    super.key,
    required this.trail,
    required this.isSelected,
    required this.isFav,
    required this.hideUnloved,
    required this.onToggleFavorite,
    required this.onTap,
    this.elevationData,
    this.isElevLoading = false,
    this.weatherData,
    this.isWeatherLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    String dP = isElevLoading
        ? "..."
        : (elevationData != null
              ? "+${elevationData![0].toStringAsFixed(0)}m"
              : (trail.ascent != null
                    ? "+${trail.ascent!.toStringAsFixed(0)}m"
                    : "N/A"));
    String dM = isElevLoading
        ? "..."
        : (elevationData != null
              ? "-${elevationData![1].toStringAsFixed(0)}m"
              : (trail.descent != null
                    ? "-${trail.descent!.toStringAsFixed(0)}m"
                    : "N/A"));

    return Card(
      color: isSelected ? Colors.white : AppTheme.cardBackground,
      shape: isSelected
          ? RoundedRectangleBorder(
              side: const BorderSide(color: AppTheme.neonOrange, width: 2),
              borderRadius: BorderRadius.circular(16),
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isSelected ? 6 : 1,
      child: Stack(
        children: [
          ListTile(
            onTap: () => onTap(trail.id),
            leading: _buildTrailSymbol(),
            title: _buildTitle(),
            subtitle: isSelected
                ? _buildDetailedSubtitle(context, dP, dM)
                : _buildMiniSubtitle(),
            trailing: IconButton(
              icon: Icon(
                hideUnloved
                    ? Icons.delete_outline
                    : (isFav ? Icons.favorite : Icons.favorite_border),
                color: hideUnloved || isFav
                    ? Colors.red
                    : AppTheme.grayUnselected,
              ),
              onPressed: () => onToggleFavorite(trail.id),
            ),
          ),
          if (trail.importance >= 80)
            Positioned(
              top: 0,
              right: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppTheme.neonOrange,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: const Text(
                  "TOP",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    if (!trail.name.contains('(')) {
      return Text(trail.name, style: AppTheme.titleStyle);
    }
    int pIdx = trail.name.indexOf('(');
    return RichText(
      text: TextSpan(
        text: trail.name.substring(0, pIdx),
        style: AppTheme.titleStyle.copyWith(fontSize: 16),
        children: [
          TextSpan(
            text: trail.name.substring(pIdx),
            style: TextStyle(
              fontWeight: FontWeight.normal,
              color: AppTheme.darkGreen.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSubtitle() {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          const Icon(Icons.straighten, size: 14, color: Colors.blueAccent),
          const SizedBox(width: 4),
          Text(
            "${trail.lengthKm.toStringAsFixed(1)} km",
            style: AppTheme.distanceStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedSubtitle(BuildContext context, String dP, String dM) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "📍 ${AppLocalizations.t('depart')}: ${trail.from ?? AppLocalizations.t('unknown')}",
            style: AppTheme.subtitleStyle,
          ),
          Text(
            "🏁 ${AppLocalizations.t('arrivee')}: ${trail.to ?? AppLocalizations.t('unknown')}",
            style: AppTheme.subtitleStyle,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildStatItem(
                Icons.straighten,
                Colors.blueAccent,
                "${trail.lengthKm.toStringAsFixed(1)} km",
              ),
              _buildStatItem(
                Icons.trending_up,
                Colors.green,
                dP,
                textColor: isElevLoading ? Colors.grey : Colors.green[700],
              ),
              _buildStatItem(
                Icons.trending_down,
                Colors.orange,
                dM,
                textColor: isElevLoading ? Colors.grey : Colors.orange[700],
              ),
            ],
          ),
          if (weatherData != null || isWeatherLoading)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                AppLocalizations.t('weatherPrefix'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ),
          if (isWeatherLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (weatherData != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weatherData!.map((wd) {
                // Assuming weatherData elements are passed as a dynamic list that behaves like WeatherDay
                return _buildWeatherItem(wd);
              }).toList(),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => GpxService.downloadGpx(trail),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text("GPX", style: TextStyle(fontSize: 12)),
                  style: AppTheme.secondaryButtonStyle.copyWith(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HikingModeScreen(trail: trail),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text("START", style: TextStyle(fontSize: 12)),
                  style: AppTheme.startButtonStyle.copyWith(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherItem(dynamic wd) {
    // This is a local UI helper, logic remains consistent with original WeatherDay
    DateTime dt = DateTime.parse(wd.date);
    String dayName = [
      'Lun',
      'Mar',
      'Mer',
      'Jeu',
      'Ven',
      'Sam',
      'Dim',
    ][dt.weekday - 1];
    return Column(
      children: [
        Text(dayName, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Icon(wd.icon, color: wd.color, size: 20),
        Text(
          "${wd.avgTemp.toStringAsFixed(0)}°",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildTrailSymbol() {
    Color topColor;
    Color? bottomColor;
    bool isDouble = true;

    if (trail.importance >= 80) {
      // GR: White over Red
      topColor = Colors.white;
      bottomColor = Colors.red;
    } else if (trail.importance >= 55) {
      // GRP: Yellow over Red
      topColor = Colors.yellow;
      bottomColor = Colors.red;
    } else {
      // PR: Yellow dash
      topColor = Colors.yellow;
      isDouble = false;
    }

    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 3.5,
            decoration: BoxDecoration(
              color: topColor,
              borderRadius: BorderRadius.circular(1),
              border: isSelected && topColor == Colors.white 
                  ? Border.all(color: Colors.black12, width: 0.5) 
                  : null,
            ),
          ),
          if (isDouble) ...[
            const SizedBox(height: 2.5),
            Container(
              width: 14,
              height: 3.5,
              decoration: BoxDecoration(
                color: bottomColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color color,
    String text, {
    Color? textColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../models/trail.dart';
import '../services/offline_data_service.dart';
import '../widgets/trail_list_view.dart';
import '../l10n/app_localizations.dart';

class TrailSearchDelegate extends SearchDelegate<Trail?> {
  
  @override
  String get searchFieldLabel => AppLocalizations.t('searchHint');

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
        return Center(child: Text(AppLocalizations.t('searchHint')));
    }
    return _buildList(context);
  }
  
  Widget _buildList(BuildContext context) {
    return FutureBuilder(
        future: OfflineDataService.loadOfflineData(),
        builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && OfflineDataService.allCachedTrails.isEmpty) {
                return const Center(child: CircularProgressIndicator());
            }

            final lowerQuery = query.toLowerCase();
            final List<Trail> matches = OfflineDataService.allCachedTrails.where((trail) {
                return trail.name.toLowerCase().contains(lowerQuery);
            }).toList();
            
            return TrailListView(
                trails: matches,
                onTrailTap: (trailId) {
                    Trail? selected = matches.where((t) => t.id == trailId).firstOrNull;
                    if (selected != null) {
                        close(context, selected);
                    }
                },
            );
        }
    );
  }
}

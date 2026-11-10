import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/profile_image_helper.dart';
import '../models/avatar_catalog.dart';
import '../models/ve_catalogs.dart';
import '../widgets/avatar_sprite.dart';
import '../widgets/instagram_photo_preview.dart';
import 'dart:convert';
import 'doctor_profile_screen.dart';
import 'clinic_profile_screen.dart';

class BrowseDoctorsTab extends StatefulWidget {
  const BrowseDoctorsTab(
      {super.key,
      this.initialSpecialty,
      this.initialQuery = '',
      this.onViewSchedule,
      this.showBackButton = false});

  final String? initialSpecialty;
  final String initialQuery;
  final VoidCallback? onViewSchedule;
  final bool showBackButton;

  @override
  State<BrowseDoctorsTab> createState() => _BrowseDoctorsTabState();
}

class _BrowseDoctorsTabState extends State<BrowseDoctorsTab> {
  bool _isLoading = true;
  List<dynamic> _doctors = [];
  List<dynamic> _clinics = [];
  String _searchType = 'Doctores'; // 'Doctores' or 'Clínicas'
  String _searchQuery = '';
  String _selectedState = 'Todos';
  String _selectedSpecialty = 'Todos';
  String _selectedSort = 'Recomendados';
  bool _filtersExpanded = false;
  String _favoritesKey = 'patient_favorite_doctors_current';
  Set<String> _favoriteIds = {};
  final TextEditingController _searchController = TextEditingController();

  List<String> get _estadosVE => ['Todos', ...veStates];

  String _normalizeSearch(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  bool _matchesSearch(String text, String query) {
    final terms = _normalizeSearch(query)
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    final normalizedText = _normalizeSearch(text);
    return terms.every(normalizedText.contains);
  }

  Future<void> _selectSpecialty() async {
    final queryController = TextEditingController();
    final selected = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) {
          final query = queryController.text.trim().toLowerCase();
          final results = medicalSpecialties
              .where((item) => item.toLowerCase().contains(query))
              .toList();
          return AlertDialog(
            title: const Text('Especialidades'),
            content: SizedBox(
              width: 420,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: queryController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por nombre',
                    ),
                    onChanged: (_) => refreshDialog(() {}),
                  ),
                  ListTile(
                    title: const Text('Todas'),
                    onTap: () => Navigator.pop(dialogContext, 'Todos'),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(results[index]),
                        selected: results[index] == _selectedSpecialty,
                        onTap: () =>
                            Navigator.pop(dialogContext, results[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    queryController.dispose();
    if (selected != null && mounted) {
      setState(() => _selectedSpecialty = selected);
    }
  }

  List<dynamic> get _filteredDoctors {
    final items = _searchType == 'Doctores' ? _doctors : _clinics;
    final filtered = items.where((item) {
      if (_selectedSort == 'Favoritos') {
        final favoriteId = _searchType == 'Doctores'
            ? item['id']?.toString() ?? ''
            : 'clinic:${item['id']}';
        if (!_favoriteIds.contains(favoriteId)) return false;
      }
      if (_searchType == 'Doctores') {
        final name = item['name']?.toString() ??
            'Dr. ${item['first_name']} ${item['last_name']}';
        if (_searchQuery.isNotEmpty && !_matchesSearch(name, _searchQuery)) {
          return false;
        }
      } else {
        final name =
            item['name']?.toString() ?? item['first_name']?.toString() ?? '';
        if (_searchQuery.isNotEmpty && !_matchesSearch(name, _searchQuery)) {
          return false;
        }
      }

      if (_selectedState != 'Todos') {
        if (item['state'] != _selectedState) return false;
      }

      if (_searchType == 'Doctores' && _selectedSpecialty != 'Todos') {
        final specialties = (item['specialties'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        if (!specialties.any((s) => s.contains(_selectedSpecialty))) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort based on _selectedSort, but ALWAYS VIP first
    filtered.sort((a, b) {
      final aVip = (a['is_vip'] == true) ? 1 : 0;
      final bVip = (b['is_vip'] == true) ? 1 : 0;

      if (aVip != bVip) {
        return bVip.compareTo(aVip);
      }

      if (_selectedSort == 'Precio más bajo') {
        final aPrice = (a['consultation_fee'] as num?)?.toDouble() ?? 0.0;
        final bPrice = (b['consultation_fee'] as num?)?.toDouble() ?? 0.0;
        return aPrice.compareTo(bPrice);
      } else if (_selectedSort == 'Precio más alto') {
        final aPrice = (a['consultation_fee'] as num?)?.toDouble() ?? 0.0;
        final bPrice = (b['consultation_fee'] as num?)?.toDouble() ?? 0.0;
        return bPrice.compareTo(aPrice);
      }

      return 0;
    });

    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery;
    _searchController.text = widget.initialQuery;
    final initialSpecialty = widget.initialSpecialty;
    if (initialSpecialty != null && initialSpecialty.trim().isNotEmpty) {
      _selectedSpecialty = initialSpecialty;
    }
    _fetchDoctors();
  }

  @override
  void didUpdateWidget(covariant BrowseDoctorsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      _searchController.text = widget.initialQuery;
      setState(() => _searchQuery = widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _saveSort(String value) {
    setState(() => _selectedSort = value);
  }

  Future<void> _fetchDoctors() async {
    try {
      final response = await ApiClient.get('/doctors/public');
      final clinicResponse = await ApiClient.get('/clinics/');
      final userResponse = await ApiClient.get('/users/me');

      List<dynamic> allDocs = [];
      List<dynamic> allClinics = [];

      if (response.statusCode == 200) {
        allDocs = jsonDecode(response.body);
      }
      if (clinicResponse.statusCode == 200) {
        allClinics = jsonDecode(clinicResponse.body);
      }
      final userState = userResponse.statusCode == 200
          ? jsonDecode(userResponse.body)['state']?.toString()
          : null;
      String? userId;
      if (userResponse.statusCode == 200) {
        userId = jsonDecode(userResponse.body)['id']?.toString();
      }
      final prefs = await SharedPreferences.getInstance();
      final favoritesKey = 'patient_favorite_doctors_${userId ?? 'current'}';
      final favoriteIds = prefs.getStringList(favoritesKey) ?? [];
      final sortKey = 'browse_sort_${userId ?? 'current'}';
      await prefs.remove(sortKey);

      if (!mounted) return;
      setState(() {
        if (userState != null && veStates.contains(userState)) {
          _selectedState = userState;
        }
        _doctors = allDocs
            .where((doc) => doc['plan'] != 'Ninguno')
            .toList();
        _clinics = allClinics;
        _favoritesKey = favoritesKey;
        _selectedSort = 'Recomendados';
        _favoriteIds = favoriteIds.toSet();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(String favoriteId) async {
    setState(() {
      if (_favoriteIds.contains(favoriteId)) {
        _favoriteIds.remove(favoriteId);
      } else {
        _favoriteIds.add(favoriteId);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favoriteIds.toList());
  }

  Future<void> _reloadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoritesKey) ?? [];
    if (mounted) setState(() => _favoriteIds = favorites.toSet());
  }

  Widget _buildFilterOptions() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFB8CCE7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B2545).withValues(alpha: .06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtrar resultados',
                  style: TextStyle(
                      color: Color(0xFF0B2545),
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _estadosVE
                    .map((state) => DropdownMenuItem(
                          value: state,
                          child: Text(state),
                        ))
                    .toList(),
                onChanged: (state) {
                  if (state != null) setState(() => _selectedState = state);
                },
              ),
              if (_searchType == 'Doctores') ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _selectSpecialty,
                  icon: const Icon(Icons.medical_services_outlined, size: 18),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_selectedSpecialty == 'Todos'
                        ? 'Todas las especialidades'
                        : _selectedSpecialty),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    alignment: Alignment.centerLeft,
                    foregroundColor: const Color(0xFF0B2545),
                    side: const BorderSide(color: Color(0xFFB8CCE7)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedSort,
                decoration: const InputDecoration(
                  labelText: 'Ordenar por',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  'Recomendados',
                  'Favoritos',
                  'Precio más bajo',
                  'Precio más alto',
                ]
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) _saveSort(value);
                },
              ),
              if (_selectedState != 'Todos' ||
                  _selectedSpecialty != 'Todos' ||
                  _selectedSort != 'Recomendados')
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedState = 'Todos';
                        _selectedSpecialty = 'Todos';
                      });
                      _saveSort('Recomendados');
                    },
                    child: const Text('Limpiar filtros'),
                  ),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3), Color(0xFFB3C6DF)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  if (widget.showBackButton) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF0B2545)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      widget.showBackButton
                          ? 'Buscar doctores y clínicas'
                          : 'Buscar',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _searchType = 'Doctores'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _searchType == 'Doctores'
                              ? const Color(0xFF0056B3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF0056B3)),
                        ),
                        child: Center(
                          child: Text('Doctores',
                              style: TextStyle(
                                  color: _searchType == 'Doctores'
                                      ? Colors.white
                                      : const Color(0xFF0056B3),
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _searchType = 'Clínicas'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _searchType == 'Clínicas'
                              ? const Color(0xFF0056B3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF0056B3)),
                        ),
                        child: Center(
                          child: Text('Clínicas',
                              style: TextStyle(
                                  color: _searchType == 'Clínicas'
                                      ? Colors.white
                                      : const Color(0xFF0056B3),
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF475569)),
                  suffixIcon: IconButton(
                    tooltip: _filtersExpanded ? 'Ocultar filtros' : 'Filtros',
                    onPressed: () =>
                        setState(() => _filtersExpanded = !_filtersExpanded),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          _filtersExpanded
                              ? Icons.tune_rounded
                              : Icons.filter_list_rounded,
                          color: const Color(0xFF0056B3),
                        ),
                        if (_selectedState != 'Todos' ||
                            _selectedSpecialty != 'Todos' ||
                            _selectedSort != 'Recomendados')
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE14B63),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 52, minHeight: 52),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _filtersExpanded
                  ? _buildFilterOptions()
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredDoctors.isEmpty
                      ? Center(
                          child: Text(
                              'No hay ${_searchType.toLowerCase()} registrados con estos filtros.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: _filteredDoctors.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = Map<String, dynamic>.from(
                                _filteredDoctors[index] as Map);
                            if (_searchType == 'Doctores') {
                              final name = item['name']?.toString() ??
                                  'Dr. ${item['first_name'] ?? ''} ${item['last_name'] ?? ''}'
                                      .trim();
                              final specialties = item['specialties'] as List?;
                              final specialty =
                                  specialties != null && specialties.isNotEmpty
                                      ? specialties.first.toString()
                                      : 'Médico general';
                              final address = item['address']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ==
                                      true
                                  ? item['address'].toString()
                                  : (item['state']?.toString() ??
                                      'Ubicación no indicada');
                              final rawFee = item['consultation_fee'];
                              final fee = rawFee is num
                                  ? rawFee.toDouble()
                                  : double.tryParse(rawFee?.toString() ?? '') ??
                                      0;
                              final cost = fee > 0
                                  ? '\$${fee.toStringAsFixed(fee == fee.roundToDouble() ? 0 : 2)} / consulta'
                                  : 'Precio no indicado';
                              final favoriteId = item['id']?.toString() ?? '';
                              return _buildDoctorCard(
                                name: name,
                                specialty: specialty,
                                address: address,
                                cost: cost,
                                isVip: item['is_vip'] == true,
                                isClinic: false,
                                imageUrl: item['avatar_url']?.toString(),
                                isFavorite: _favoriteIds.contains(favoriteId),
                                onFavoriteTap: favoriteId.isEmpty
                                    ? null
                                    : () => _toggleFavorite(favoriteId),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => DoctorProfileScreen(
                                        doctor: item,
                                        onViewSchedule: widget.onViewSchedule,
                                      ),
                                    ),
                                  );
                                  await _reloadFavorites();
                                },
                              );
                            }

                            final name = item['name']?.toString() ??
                                item['first_name']?.toString() ??
                                'Clínica';
                            final specialty =
                                item['type']?.toString() ?? 'Centro de salud';
                            final address = item['city']?.toString() ??
                                item['address']?.toString() ??
                                'Ubicación no indicada';
                            final favoriteId = 'clinic:${item['id']}';
                            return _buildDoctorCard(
                              name: name,
                              specialty: specialty,
                              address: address,
                              cost: 'Ver clínica',
                              isVip: item['is_vip'] == true,
                              isClinic: true,
                              imageUrl: item['avatar_url']?.toString(),
                              isFavorite: _favoriteIds.contains(favoriteId),
                              onFavoriteTap: item['id'] == null
                                  ? null
                                  : () => _toggleFavorite(favoriteId),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ClinicProfileScreen(clinic: item),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(
      {required String name,
      required String specialty,
      required String address,
      required String cost,
      required bool isVip,
      required bool isClinic,
      required String? imageUrl,
      required bool isFavorite,
      required VoidCallback? onFavoriteTap,
      required VoidCallback onTap}) {
    const teal = Color(0xFF1A746B);
    return Material(
      color: const Color(0xFFFFFEFA),
      borderRadius: BorderRadius.circular(22),
      elevation: 2,
      shadowColor: const Color(0xFF26372C).withValues(alpha: 0.14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () {
                          InstagramPhotoPreview.show(
                            context,
                            imageUrl: imageUrl,
                            fallbackRole: isClinic ? 'clinic' : 'doctor',
                            title: name,
                            subtitle: specialty,
                          );
                        },
                        child: _buildCardPhoto(imageUrl, isClinic),
                      ),
                      if (isVip)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDFB84E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 11, color: Colors.white),
                                SizedBox(width: 3),
                                Text('VIP',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: SizedBox(
                  height: 112,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF17212B),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                          if (onFavoriteTap != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                  width: 36, height: 36),
                              padding: EdgeInsets.zero,
                              onPressed: onFavoriteTap,
                              tooltip: isFavorite
                                  ? 'Quitar de favoritos'
                                  : 'Añadir a favoritos',
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorite
                                    ? const Color(0xFFE04F62)
                                    : const Color(0xFF68737D),
                                size: 21,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        specialty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: teal,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: Color(0xFF7C8A7B), size: 14),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFF66716D), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        cost,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF202820),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardPhoto(String? imageUrl, bool isClinic) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      final preset = AvatarCatalog.parse(imageUrl);
      if (preset != null) {
        return AvatarSprite(
          role: preset.role,
          index: preset.index,
          size: 112,
        );
      }
      try {
        return Image(
          image: ProfileImageHelper.getProfileImageProvider(imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _cardPhotoPlaceholder(isClinic),
        );
      } catch (_) {}
    }
    return _cardPhotoPlaceholder(isClinic);
  }

  Widget _cardPhotoPlaceholder(bool isClinic) {
    return AvatarSprite(
      role: isClinic ? 'clinic' : 'doctor',
      index: 0,
      size: 112,
    );
  }
}

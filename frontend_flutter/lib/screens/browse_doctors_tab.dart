import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/profile_avatar.dart';
import '../models/ve_catalogs.dart';
import 'dart:convert';
import 'doctor_profile_screen.dart';
import 'clinic_profile_screen.dart';

class BrowseDoctorsTab extends StatefulWidget {
  const BrowseDoctorsTab({super.key});

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

  List<String> get _estadosVE => ['Todos', ...veStates];

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
      if (_searchType == 'Doctores') {
        final name =
            'Dr. ${item['first_name']} ${item['last_name']}'.toLowerCase();
        if (_searchQuery.isNotEmpty &&
            !name.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      } else {
        final name = '${item['first_name']}'.toLowerCase();
        if (_searchQuery.isNotEmpty &&
            !name.contains(_searchQuery.toLowerCase())) {
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
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      final response = await ApiClient.get('/admin/doctors');
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

      if (!mounted) return;
      setState(() {
        if (userState != null && veStates.contains(userState)) {
          _selectedState = userState;
        }
        _doctors = allDocs
            .where(
                (doc) => doc['plan'] != 'Ninguno' || doc['clinic_id'] != null)
            .toList();
        _clinics = allClinics;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

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
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Buscar',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B2545))),
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
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF475569)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0B2545)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedState,
                    isExpanded: true,
                    items: _estadosVE.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedState = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: OutlinedButton.icon(
                onPressed: _selectSpecialty,
                icon: const Icon(Icons.search, color: Color(0xFF0056B3)),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_selectedSpecialty == 'Todos'
                      ? 'Especialidades'
                      : _selectedSpecialty),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  alignment: Alignment.centerLeft,
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  foregroundColor: const Color(0xFF0B2545),
                  side: const BorderSide(color: Color(0xFF0B2545)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF0056B3).withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedSort,
                    icon: const Icon(Icons.sort, color: Color(0xFF0056B3)),
                    items: [
                      'Recomendados',
                      'Precio más bajo',
                      'Precio más alto'
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value,
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF0B2545))),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedSort = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredDoctors.isEmpty
                      ? Center(
                          child: Text(
                              'No hay ${_searchType.toLowerCase()} registrados con estos filtros.'))
                      : LayoutBuilder(builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 600 ? 3 : 2;
                          const gap = 12.0;
                          final cardWidth = (constraints.maxWidth -
                                  32 -
                                  gap * (columns - 1)) /
                              columns;
                          return SingleChildScrollView(
                            padding: const EdgeInsets.only(
                                left: 16.0, right: 16.0, bottom: 100.0),
                            child: Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: _filteredDoctors.map((item) {
                                if (_searchType == 'Doctores') {
                                  final name =
                                      'Dr. ${item['first_name']} ${item['last_name']}';
                                  final specialty =
                                      (item['specialties'] != null &&
                                              item['specialties'].isNotEmpty)
                                          ? item['specialties'][0]
                                          : 'Médico General';
                                  final address = item['address']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                      ? item['address'].toString()
                                      : (item['state'] ?? 'Sin ubicación');
                                  final fee = (item['consultation_fee'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  final cost = '\$${fee.toStringAsFixed(2)}';
                                  final isVip = item['is_vip'] == true;
                                  return SizedBox(
                                      width: cardWidth,
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      DoctorProfileScreen(
                                                          doctor: item)));
                                        },
                                        child: _buildDoctorCard(
                                          name: name,
                                          specialty: specialty,
                                          address: address,
                                          cost: cost,
                                          isVip: isVip,
                                          isClinic: false,
                                          imageUrl: item['avatar_url'],
                                        ),
                                      ));
                                } else {
                                  final name = item['first_name'] ?? 'Clínica';
                                  const specialty = 'Clínica';
                                  final address = item['address']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                      ? item['address'].toString()
                                      : (item['state'] ?? 'Sin ubicación');
                                  final isVip = item['is_vip'] == true;
                                  return SizedBox(
                                      width: cardWidth,
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      ClinicProfileScreen(
                                                          clinic: item)));
                                        },
                                        child: _buildDoctorCard(
                                          name: name,
                                          specialty: specialty,
                                          address: address,
                                          cost: item['phone'] ?? 'Sin contacto',
                                          isVip: isVip,
                                          isClinic: true,
                                          imageUrl: item['avatar_url'],
                                        ),
                                      ));
                                }
                              }).toList(),
                            ),
                          );
                        }),
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
      required String? imageUrl}) {
    const vipGold = Color(0xFFD7AF48);
    return Container(
      padding: EdgeInsets.all(isVip ? 3 : 1),
      decoration: BoxDecoration(
        color: isVip ? vipGold : const Color(0xFFDCE7F2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isVip ? vipGold : const Color(0xFF0B2545))
                .withValues(alpha: isVip ? 0.24 : 0.10),
            blurRadius: isVip ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Container(
          color: Colors.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final avatarSize = constraints.maxWidth < 200 ? 72.0 : 82.0;
              final headerHeight = constraints.maxWidth < 200 ? 58.0 : 66.0;
              final overlap = avatarSize / 2;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: headerHeight,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF174F88), Color(0xFF073B70)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(painter: _MedicalCardDotsPainter()),
                      ),
                      Positioned(
                        left: 12,
                        top: 4,
                        child: Icon(Icons.add,
                            size: constraints.maxWidth < 200 ? 42 : 54,
                            color: Colors.white),
                      ),
                      if (isVip)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: vipGold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 12, color: Colors.white),
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
                      Positioned(
                        bottom: -overlap,
                        child: Container(
                          padding: EdgeInsets.all(isVip ? 4 : 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isVip ? vipGold : Colors.white,
                            border: Border.all(
                              color: isVip ? vipGold : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: ProfileAvatar(
                            imageUrl: imageUrl,
                            fallbackRole: isClinic ? 'clinic' : 'doctor',
                            size: avatarSize,
                            borderColor: Colors.white,
                            borderWidth: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: overlap + 3),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF174F88),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          specialty,
                          style: const TextStyle(
                            color: Color(0xFF17212B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on,
                                size: 15, color: Color(0xFF174F88)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                address,
                                style: const TextStyle(
                                    color: Color(0xFF475569), fontSize: 11),
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: 1,
                          color: const Color(0xFFCBD5E1),
                        ),
                        if (cost.isNotEmpty)
                          Text(
                            cost,
                            style: const TextStyle(
                              color: Color(0xFF101820),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else if (isClinic)
                          const Text(
                            'Clínica',
                            style: TextStyle(
                              color: Color(0xFF101820),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MedicalCardDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.42);
    for (var y = 12.0; y < size.height; y += 18) {
      for (var x = size.width * 0.32; x < size.width; x += 19) {
        canvas.drawCircle(Offset(x, y), 2.2, paint);
      }
    }
    final outline = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(size.width * 0.67, -4), 28, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/profile_image_helper.dart';
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

  final List<String> _estadosVE = [
    'Todos', "Amazonas", "Anzoátegui", "Apure", "Aragua", "Barinas", "Bolívar", "Carabobo", "Cojedes",
    "Delta Amacuro", "Dependencias Federales", "Distrito Capital", "Falcón", "Guárico", "La Guaira", "Lara",
    "Mérida", "Miranda", "Monagas", "Nueva Esparta", "Portuguesa", "Sucre", "Táchira",
    "Trujillo", "Yaracuy", "Zulia"
  ];

  List<dynamic> get _filteredDoctors {
    final items = _searchType == 'Doctores' ? _doctors : _clinics;
    final filtered = items.where((item) {
      if (_searchType == 'Doctores') {
        final name = 'Dr. ${item['first_name']} ${item['last_name']}'.toLowerCase();
        if (_searchQuery.isNotEmpty && !name.contains(_searchQuery.toLowerCase())) return false;
      } else {
        final name = '${item['first_name']}'.toLowerCase();
        if (_searchQuery.isNotEmpty && !name.contains(_searchQuery.toLowerCase())) return false;
      }
      
      if (_selectedState != 'Todos') {
        if (item['state'] != _selectedState) return false;
      }

      if (_searchType == 'Doctores' && _selectedSpecialty != 'Todos') {
        final specialties = (item['specialties'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        if (!specialties.any((s) => s.contains(_selectedSpecialty))) return false;
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
      final clinicResponse = await ApiClient.get('/clinics');
      
      List<dynamic> allDocs = [];
      List<dynamic> allClinics = [];
      
      if (response.statusCode == 200) {
        allDocs = jsonDecode(response.body);
      }
      if (clinicResponse.statusCode == 200) {
        allClinics = jsonDecode(clinicResponse.body);
      }
      
      setState(() {
        _doctors = allDocs.where((doc) => doc['plan'] != 'Ninguno' || doc['clinic_id'] != null).toList();
        _clinics = allClinics;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
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
              child: Text('Buscar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
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
                          color: _searchType == 'Doctores' ? const Color(0xFF0056B3) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF0056B3)),
                        ),
                        child: Center(
                          child: Text('Doctores', style: TextStyle(
                            color: _searchType == 'Doctores' ? Colors.white : const Color(0xFF0056B3),
                            fontWeight: FontWeight.bold
                          )),
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
                          color: _searchType == 'Clínicas' ? const Color(0xFF0056B3) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF0056B3)),
                        ),
                        child: Center(
                          child: Text('Clínicas', style: TextStyle(
                            color: _searchType == 'Clínicas' ? Colors.white : const Color(0xFF0056B3),
                            fontWeight: FontWeight.bold
                          )),
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
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF475569)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
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
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GestureDetector(onTap: () => setState(() => _selectedSpecialty = 'Todos'), child: _buildChip('Todos', isSelected: _selectedSpecialty == 'Todos')),
                  GestureDetector(onTap: () => setState(() => _selectedSpecialty = 'Alergología e Inmunología'), child: _buildChip('Alergología e Inmunología', isSelected: _selectedSpecialty == 'Alergología e Inmunología')),
                  GestureDetector(onTap: () => setState(() => _selectedSpecialty = 'Cardiología'), child: _buildChip('Cardiología', isSelected: _selectedSpecialty == 'Cardiología')),
                  GestureDetector(onTap: () => setState(() => _selectedSpecialty = 'Cirugía General'), child: _buildChip('Cirugía General', isSelected: _selectedSpecialty == 'Cirugía General')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0056B3).withOpacity(0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedSort,
                    icon: const Icon(Icons.sort, color: Color(0xFF0056B3)),
                    items: ['Recomendados', 'Precio más bajo', 'Precio más alto']
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF0B2545))),
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
                  ? Center(child: Text('No hay ${_searchType.toLowerCase()} registrados con estos filtros.'))
                  : GridView.builder(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 100.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.65, // Adjust this ratio to make them fit nicely
                      ),
                      itemCount: _filteredDoctors.length,
                      itemBuilder: (context, index) {
                        final item = _filteredDoctors[index];
                        
                        if (_searchType == 'Doctores') {
                          final name = 'Dr. ${item['first_name']} ${item['last_name']}';
                          final specialty = (item['specialties'] != null && item['specialties'].isNotEmpty) ? item['specialties'][0] : 'Médico General';
                          final address = item['address'] ?? 'Sin dirección';
                          final cost = item['consultation_fee'] != null ? '\$${item['consultation_fee']}' : '\$0.0';
                          final isVip = item['is_vip'] == true;
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => DoctorProfileScreen(doctor: item)));
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
                          );
                        } else {
                          final name = item['first_name'] ?? 'Clínica';
                          final specialty = 'Clínica';
                          final address = item['address'] ?? 'Sin dirección';
                          final isVip = item['is_vip'] == true;
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ClinicProfileScreen(clinic: item)));
                            },
                            child: _buildDoctorCard(
                              name: name,
                              specialty: specialty,
                              address: address,
                              cost: item['phone'] ?? '',
                              isVip: isVip,
                              isClinic: true,
                              imageUrl: item['avatar_url'],
                            ),
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, {required bool isSelected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0056B3) : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF0B2545),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12, // Reduced font size
        ),
      ),
    );
  }

  Widget _buildDoctorCard({required String name, required String specialty, required String address, required String cost, required bool isVip, required bool isClinic, required String? imageUrl}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: isVip ? Border.all(color: const Color(0xFFFFC107), width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: isVip 
              ? Icon(isClinic ? Icons.local_hospital : Icons.star, color: const Color(0xFFFFC107), size: 18) 
              : const SizedBox(height: 18),
          ),
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isVip ? Border.all(color: const Color(0xFFFFC107), width: 3) : null,
              image: DecorationImage(image: ProfileImageHelper.getProfileImageProvider(imageUrl), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name, 
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B2545)),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  specialty, 
                  style: const TextStyle(color: Color(0xFF0056B3), fontSize: 11, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on, size: 10, color: Color(0xFF475569)),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(color: Color(0xFF475569), fontSize: 10),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (cost.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0056B3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cost,
                      style: const TextStyle(color: Color(0xFF0056B3), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

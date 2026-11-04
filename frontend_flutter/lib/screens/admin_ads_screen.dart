import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';

class AdminAdsScreen extends StatefulWidget {
  const AdminAdsScreen({super.key});

  @override
  State<AdminAdsScreen> createState() => _AdminAdsScreenState();
}

class _AdminAdsScreenState extends State<AdminAdsScreen> {
  static const _blue = Color(0xFF0756A4);
  static const _roles = <String, String>{
    'patient': 'Pacientes',
    'doctor': 'Doctores',
    'assistant': 'Asistentes',
    'clinic': 'Clínicas',
  };

  final _titleController = TextEditingController();
  final _linkController = TextEditingController();
  final _picker = ImagePicker();
  final Set<String> _targetRoles = _roles.keys.toSet();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  DateTime _expiration = DateTime.now().add(const Duration(days: 7));
  List<Map<String, dynamic>> _ads = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _loadAds() async {
    try {
      final response = await ApiClient.get('/ads/admin');
      if (!mounted) return;
      if (response.statusCode != 200) {
        throw Exception(_errorMessage(
            response.body, 'No se pudieron cargar los anuncios.'));
      }
      final data = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _ads =
            data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _chooseImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      final extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';
      if (!{'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(extension)) {
        _showMessage('Selecciona una imagen JPG, PNG, WEBP o GIF.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
        _showMessage('La imagen debe pesar menos de 8 MB.');
        return;
      }
      setState(() {
        _selectedImage = file;
        _selectedImageBytes = bytes;
      });
    } catch (_) {
      _showMessage('No se pudo abrir la galería. Intenta con otra imagen.');
    }
  }

  Future<void> _chooseExpiration() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiration.isAfter(DateTime.now())
          ? _expiration
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Fecha de expiración',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expiration),
      helpText: 'Hora de expiración',
    );
    if (time == null || !mounted) return;
    setState(() => _expiration = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ));
  }

  Future<void> _createAd() async {
    if (_selectedImage == null) {
      _showMessage('Selecciona la imagen del anuncio.');
      return;
    }
    if (_targetRoles.isEmpty) {
      _showMessage('Selecciona al menos un tipo de usuario.');
      return;
    }
    if (!_expiration.isAfter(DateTime.now())) {
      _showMessage('La fecha de expiración debe estar en el futuro.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final response = await ApiClient.uploadMultipart(
        '/ads/admin',
        bytes: _selectedImageBytes!,
        filename: _selectedImage!.name,
        fields: {
          'title': _titleController.text.trim().isEmpty
              ? 'Anuncio de Salud Now'
              : _titleController.text.trim(),
          'target_roles': jsonEncode(_targetRoles.toList()),
          'expires_at': _expiration.toUtc().toIso8601String(),
          'link_url': _linkController.text.trim(),
        },
      );
      if (!mounted) return;
      if (response.statusCode != 201) {
        throw Exception(
            _errorMessage(response.body, 'No se pudo publicar el anuncio.'));
      }
      _titleController.clear();
      _linkController.clear();
      setState(() {
        _selectedImage = null;
        _selectedImageBytes = null;
      });
      _showMessage('Anuncio publicado.');
      await _loadAds();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deactivateAd(int id) async {
    try {
      final response = await ApiClient.delete('/ads/admin/$id');
      if (!mounted) return;
      if (response.statusCode != 200) {
        throw Exception(_errorMessage(response.body, 'No se pudo desactivar.'));
      }
      await _loadAds();
    } catch (error) {
      if (mounted)
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _errorMessage(String body, String fallback) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['detail'] != null) {
        final detail = data['detail'].toString();
        if (detail == 'Not Found') {
          return 'Servicio de anuncios no encontrado en el servidor remoto (aún no desplegado).';
        }
        return detail;
      }
    } catch (_) {}
    if (body.contains('Method Not Allowed')) {
      return 'Método no permitido (405): El backend de anuncios aún no está activo en producción.';
    }
    return fallback;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFE0EAFC),
        appBar: AppBar(
          title: const Text('Anuncios flotantes'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0B2545),
        ),
        body: RefreshIndicator(
          onRefresh: _loadAds,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _buildComposer(),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text('Anuncios publicados',
                        style: TextStyle(
                            fontSize: 19,
                            color: Color(0xFF0B2545),
                            fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: _loadAds,
                    icon: const Icon(Icons.refresh_rounded, color: _blue),
                  ),
                ],
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_ads.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('Aún no hay anuncios publicados.'),
                )
              else
                ..._ads.map(_buildAdCard),
            ],
          ),
        ),
      );

  Widget _buildComposer() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2545).withValues(alpha: .08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Crear anuncio',
                style: TextStyle(
                    color: Color(0xFF0B2545),
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Título (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _chooseImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_selectedImage == null
                  ? 'Elegir imagen'
                  : _selectedImage!.name),
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  _selectedImageBytes!,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 80,
                    child: Center(child: Text('Vista previa no disponible')),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text('Mostrar a',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 6,
              children: _roles.entries
                  .map((entry) => FilterChip(
                        label: Text(entry.value),
                        selected: _targetRoles.contains(entry.key),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _targetRoles.add(entry.key);
                          } else {
                            _targetRoles.remove(entry.key);
                          }
                        }),
                      ))
                  .toList(),
            ),
            OutlinedButton.icon(
              onPressed: _chooseExpiration,
              icon: const Icon(Icons.event_available_outlined),
              label:
                  Text('Expira: ${_formatDate(_expiration.toIso8601String())}'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _linkController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Enlace al tocar (opcional)',
                hintText: 'https://…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0756A4), Color(0xFF0A3D78)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _createAd,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.campaign_outlined, color: Colors.white),
                label: Text(_isSaving ? 'Publicando…' : 'Publicar anuncio',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final id = int.tryParse(ad['id']?.toString() ?? '');
    final roles = (ad['target_roles'] as List<dynamic>? ?? [])
        .map((role) => _roles[role.toString()] ?? role.toString())
        .join(', ');
    final isActive = ad['is_active'] == true &&
        (DateTime.tryParse(ad['expires_at']?.toString() ?? '')
                ?.isAfter(DateTime.now().toUtc()) ??
            false);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: Image.network(
              _imageUrl(ad['image_url']?.toString()),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFE5EFFB),
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(ad['title']?.toString() ?? 'Anuncio',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B2545))),
                    ),
                    if (isActive)
                      IconButton(
                        tooltip: 'Desactivar anuncio',
                        onPressed: id == null ? null : () => _deactivateAd(id),
                        icon: const Icon(Icons.visibility_off_outlined,
                            color: Color(0xFF64748B)),
                      ),
                  ],
                ),
                Text('Público: $roles',
                    style: const TextStyle(color: Color(0xFF475569))),
                const SizedBox(height: 4),
                Text('Expira: ${_formatDate(ad['expires_at']?.toString())}',
                    style: const TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 18, color: _blue),
                    const SizedBox(width: 5),
                    Text('${ad['views'] ?? 0} vistas'),
                    const SizedBox(width: 18),
                    const Icon(Icons.touch_app_outlined,
                        size: 18, color: _blue),
                    const SizedBox(width: 5),
                    Text('${ad['clicks'] ?? 0} clics'),
                    const Spacer(),
                    Text(isActive ? 'Activo' : 'Finalizado',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.green : Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _imageUrl(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://'))
      return value;
    return 'https://saludnow.site${value.startsWith('/') ? '' : '/'}$value';
  }
}

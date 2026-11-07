import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../screens/agendar_cita_tab.dart';
import '../screens/doctor_profile_screen.dart';
import 'profile_avatar.dart';

class ClickMessage {
  final bool isUser;
  final String text;
  final List<dynamic> doctors;
  final String? specialty;
  final String? startDate;
  final String? endDate;

  ClickMessage({
    required this.isUser,
    required this.text,
    this.doctors = const [],
    this.specialty,
    this.startDate,
    this.endDate,
  });
}

class ClickAssistantSection extends StatefulWidget {
  final VoidCallback? onCitaAgendada;

  const ClickAssistantSection({super.key, this.onCitaAgendada});

  @override
  State<ClickAssistantSection> createState() => ClickAssistantSectionState();
}

class ClickAssistantSectionState extends State<ClickAssistantSection>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode inputFocusNode = FocusNode();
  final GlobalKey inputContainerKey = GlobalKey();
  late AnimationController _floatAnimController;
  late Animation<double> _floatAnimation;

  void focusAndScrollToInput() {
    inputFocusNode.requestFocus();
    final ctx = inputContainerKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.85,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _isLoading = false;
  final List<ClickMessage> _messages = [];

  final List<String> _suggestions = [
    'Quiero una cita con un odontólogo este martes',
    '¿Qué doctores de ginecología hay disponibles la semana que viene?',
    'Cardiólogo disponible mañana',
    'Pediatría este viernes',
  ];

  @override
  void initState() {
    super.initState();

    // Animación de flotación suave para la mascota Click
    _floatAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _floatAnimController,
        curve: Curves.easeInOutSine,
      ),
    );

    // Mensaje de bienvenida inicial de Click
    _messages.add(
      ClickMessage(
        isUser: false,
        text:
            '¡Hola! Soy **Click**, tu asistente médico inteligente de Salud Now 🤖\n\n'
            'Dime qué especialista necesitas o para qué fecha '
            '(ej: *"Quiero una cita con un odontólogo este martes"* o *"¿Qué doctores de ginecología hay la semana que viene?"*) '
            'y encontraré turnos libres para agendar tu cita en un click!',
      ),
    );
  }

  @override
  void dispose() {
    _floatAnimController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? customText]) async {
    final query = (customText ?? _textController.text).trim();
    if (query.isEmpty || _isLoading) return;

    _textController.clear();
    HapticFeedback.lightImpact();

    setState(() {
      _messages.add(ClickMessage(isUser: true, text: query));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final data = await _processQuery(query);
      final answer = data['mensaje_respuesta']?.toString() ??
          'Aquí tienes los resultados encontrados:';
      final doctorsList = data['doctors'] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          _messages.add(
            ClickMessage(
              isUser: false,
              text: answer,
              doctors: doctorsList,
              specialty: data['especialidad']?.toString(),
              startDate: data['fecha_inicio']?.toString(),
              endDate: data['fecha_fin']?.toString(),
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ClickMessage(
              isUser: false,
              text:
                  'No pude consultar los turnos en este momento. Por favor verifica tu conexión e inténtalo de nuevo.',
            ),
          );
          _isLoading = false;
        });
      }
    }

    _scrollToBottom();
  }

  Future<Map<String, dynamic>> _processQuery(String query) async {
    // 1. Intentar llamar al backend primero
    try {
      final now = DateTime.now();
      final currentDateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final response = await ApiClient.post(
        '/assistant/chat',
        {
          'message': query,
          'current_date': currentDateStr,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> &&
            data.containsKey('mensaje_respuesta')) {
          return data;
        }
      }
    } catch (_) {}

    // 2. Procesamiento Inteligente Local (Natural Language + BD Salud Now)
    return await _localAssistantSearch(query);
  }

  Future<Map<String, dynamic>> _localAssistantSearch(String query) async {
    final clean = query.toLowerCase();
    final now = DateTime.now();

    // 1. Detectar si el usuario pide explícitamente medicina general
    final bool isExplicitGeneral = clean.contains('general') ||
        clean.contains('familiar') ||
        clean.contains('medicina interna') ||
        clean.contains('internista') ||
        clean.contains('médico general') ||
        clean.contains('medico general') ||
        clean.contains('médico de cabecera') ||
        clean.contains('medico de cabecera') ||
        clean.contains('consulta general');

    // 2. Diccionario exhaustivo de especialidades médicas y sinónimos
    String? detectedSpecialty;

    if (clean.contains('hematol') || clean.contains('sangre')) {
      detectedSpecialty = 'Hematología';
    } else if (clean.contains('cardio') ||
        clean.contains('corazon') ||
        clean.contains('corazón')) {
      detectedSpecialty = 'Cardiología';
    } else if (clean.contains('odont') ||
        clean.contains('dent') ||
        clean.contains('diente') ||
        clean.contains('muela') ||
        clean.contains('ortodon')) {
      detectedSpecialty = 'Odontología';
    } else if (clean.contains('gine') ||
        clean.contains('embaraz') ||
        clean.contains('obstet') ||
        clean.contains('parto')) {
      detectedSpecialty = 'Ginecología y Obstetricia';
    } else if (clean.contains('pediat') ||
        clean.contains('niñ') ||
        clean.contains('bebe') ||
        clean.contains('bebé') ||
        clean.contains('infant')) {
      detectedSpecialty = 'Pediatría';
    } else if (clean.contains('derma') ||
        clean.contains('piel') ||
        clean.contains('cutane') ||
        clean.contains('acne') ||
        clean.contains('acné')) {
      detectedSpecialty = 'Dermatología';
    } else if (clean.contains('oftalm') ||
        clean.contains('ojo') ||
        clean.contains('vista') ||
        clean.contains('oculist')) {
      detectedSpecialty = 'Oftalmología';
    } else if (clean.contains('trauma') ||
        clean.contains('hueso') ||
        clean.contains('fractur') ||
        clean.contains('ortoped')) {
      detectedSpecialty = 'Traumatología';
    } else if (clean.contains('urolo') ||
        clean.contains('prostata') ||
        clean.contains('próstata') ||
        clean.contains('urinari')) {
      detectedSpecialty = 'Urología';
    } else if (clean.contains('neuro') || clean.contains('cerebro')) {
      detectedSpecialty = 'Neurología';
    } else if (clean.contains('otorrino') ||
        clean.contains('oido') ||
        clean.contains('oído') ||
        clean.contains('garganta') ||
        clean.contains('nariz')) {
      detectedSpecialty = 'Otorrinolaringología';
    } else if (clean.contains('nutri') ||
        clean.contains('diet') ||
        clean.contains('peso') ||
        clean.contains('aliment')) {
      detectedSpecialty = 'Nutrición y Dietética';
    } else if (clean.contains('alerg')) {
      detectedSpecialty = 'Alergología';
    } else if (clean.contains('gastro') ||
        clean.contains('estomago') ||
        clean.contains('estómago') ||
        clean.contains('digestiv') ||
        clean.contains('colon') ||
        clean.contains('endoscop')) {
      detectedSpecialty = 'Gastroenterología';
    } else if (clean.contains('oncol') ||
        clean.contains('cancer') ||
        clean.contains('cáncer') ||
        clean.contains('tumor')) {
      detectedSpecialty = 'Oncología';
    } else if (clean.contains('endocrin') ||
        clean.contains('tiroides') ||
        clean.contains('diabetes') ||
        clean.contains('hormon')) {
      detectedSpecialty = 'Endocrinología';
    } else if (clean.contains('nefrol') ||
        clean.contains('riñon') ||
        clean.contains('riñón') ||
        clean.contains('renal')) {
      detectedSpecialty = 'Nefrología';
    } else if (clean.contains('neumon') ||
        clean.contains('neumol') ||
        clean.contains('pulmon') ||
        clean.contains('pulmón') ||
        clean.contains('respirat')) {
      detectedSpecialty = 'Neumonología';
    } else if (clean.contains('reumat') ||
        clean.contains('artritis') ||
        clean.contains('artrosis') ||
        clean.contains('lupus')) {
      detectedSpecialty = 'Reumatología';
    } else if (clean.contains('infectol') ||
        clean.contains('infecc') ||
        clean.contains('virus')) {
      detectedSpecialty = 'Infectología';
    } else if (clean.contains('psiquiat')) {
      detectedSpecialty = 'Psiquiatría';
    } else if (clean.contains('psicol') ||
        clean.contains('terapia') ||
        clean.contains('salud mental')) {
      detectedSpecialty = 'Psicología';
    } else if (clean.contains('geriatr') ||
        clean.contains('adulto mayor') ||
        clean.contains('ancian') ||
        clean.contains('vejez')) {
      detectedSpecialty = 'Geriatría';
    } else if (clean.contains('cirug') ||
        clean.contains('cirujan') ||
        clean.contains('operaci')) {
      detectedSpecialty = 'Cirugía General';
    } else if (clean.contains('anestesi')) {
      detectedSpecialty = 'Anestesiología';
    } else if (clean.contains('inmunol')) {
      detectedSpecialty = 'Inmunología';
    } else if (clean.contains('fisioterap') ||
        clean.contains('fisiat') ||
        clean.contains('rehabilitac')) {
      detectedSpecialty = 'Fisioterapia';
    } else if (clean.contains('mastol') ||
        clean.contains('mama') ||
        clean.contains('seno')) {
      detectedSpecialty = 'Mastología';
    } else if (clean.contains('proctol')) {
      detectedSpecialty = 'Proctología';
    } else if (clean.contains('angiolog') ||
        clean.contains('vascular') ||
        clean.contains('varice') ||
        clean.contains('várices')) {
      detectedSpecialty = 'Angiología y Cirugía Vascular';
    } else if (clean.contains('toxicolog')) {
      detectedSpecialty = 'Toxicología';
    } else if (clean.contains('foniatr') ||
        clean.contains('fonoaudiolog')) {
      detectedSpecialty = 'Foniatría';
    } else if (clean.contains('genetist') || clean.contains('genétic')) {
      detectedSpecialty = 'Genética Médica';
    } else if (clean.contains('podolog') || clean.contains('podólog')) {
      detectedSpecialty = 'Podología';
    } else if (isExplicitGeneral) {
      detectedSpecialty = 'Medicina General';
    }

    // 3. Fallback inteligente: capturar cualquier sufijo médico común (-ólogo, -iatra, etc.)
    if (detectedSpecialty == null && !isExplicitGeneral) {
      final match = RegExp(
        r'\b([a-záéíóúñ]+(ólog[oa]s?|olog[oa]s?|iatras?|iatr[íi]as?|olog[íi]as?))\b',
        caseSensitive: false,
      ).firstMatch(clean);
      if (match != null) {
        String word = match.group(1)!;
        word = word[0].toUpperCase() + word.substring(1).toLowerCase();
        detectedSpecialty = word;
      }
    }

    final bool isGeneralRequest =
        isExplicitGeneral || detectedSpecialty == null;
    final String specialty = detectedSpecialty ?? 'Medicina General';

    // 2. Detectar día / fecha
    DateTime targetDate = now;
    final isNextWeek = clean.contains('semana que viene') ||
        clean.contains('próxima semana') ||
        clean.contains('proxima semana');

    final daysMap = {
      'lunes': 1,
      'martes': 2,
      'miercoles': 3,
      'miércoles': 3,
      'jueves': 4,
      'viernes': 5,
      'sabado': 6,
      'sábado': 6,
      'domingo': 7,
    };

    int? targetWeekday;
    for (final entry in daysMap.entries) {
      if (clean.contains(entry.key)) {
        targetWeekday = entry.value;
        break;
      }
    }

    if (targetWeekday != null) {
      int daysAhead = (targetWeekday - now.weekday);
      if (daysAhead <= 0 ||
          clean.contains('proximo') ||
          clean.contains('próximo') ||
          isNextWeek) {
        daysAhead += 7;
      }
      targetDate = now.add(Duration(days: daysAhead));
    } else if (clean.contains('mañana') || clean.contains('manana')) {
      targetDate = now.add(const Duration(days: 1));
    } else if (clean.contains('pasado mañana') ||
        clean.contains('pasado manana')) {
      targetDate = now.add(const Duration(days: 2));
    } else if (clean.contains('hoy')) {
      targetDate = now;
    } else if (isNextWeek) {
      int daysToNextMonday = (1 - now.weekday + 7) % 7;
      if (daysToNextMonday == 0) daysToNextMonday = 7;
      targetDate = now.add(Duration(days: daysToNextMonday));
    }

    final dateStr =
        '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    // 3. Obtener tasa BCV real
    double bcvRate = 896.12;
    try {
      final bcvRes = await ApiClient.get('/users/bcv-rate');
      if (bcvRes.statusCode == 200) {
        final bcvData = jsonDecode(bcvRes.body);
        final rate = bcvData['rate'];
        if (rate is num) bcvRate = rate.toDouble();
      }
    } catch (_) {}

    // 4. Obtener doctores de la base de datos
    List<dynamic> allDoctors = [];
    try {
      final docsRes = await ApiClient.get('/doctors/public');
      if (docsRes.statusCode == 200) {
        allDoctors = jsonDecode(docsRes.body) as List<dynamic>;
      }
    } catch (_) {}

    String normalizeText(String text) {
      var withAccents = 'áéíóúÁÉÍÓÚñÑüÜ';
      var withoutAccents = 'aeiouAEIOUnNuU';
      var res = text;
      for (int i = 0; i < withAccents.length; i++) {
        res = res.replaceAll(withAccents[i], withoutAccents[i]);
      }
      return res.toLowerCase().trim();
    }

    final normSpec = normalizeText(specialty);

    // Filtrar doctores que tengan esa especialidad
    List<dynamic> matchingDocs = [];
    if (!isGeneralRequest) {
      matchingDocs = allDoctors.where((d) {
        final specs = (d['specialties'] as List<dynamic>? ?? [])
            .map((s) => normalizeText(s.toString()))
            .toList();
        return specs.any((s) => s.contains(normSpec) || normSpec.contains(s));
      }).toList();
    } else {
      matchingDocs = allDoctors.where((d) {
        final specs = (d['specialties'] as List<dynamic>? ?? [])
            .map((s) => normalizeText(s.toString()))
            .toList();
        return specs.any((s) =>
            s.contains('general') ||
            s.contains('familiar') ||
            s.contains('interna'));
      }).toList();
      if (matchingDocs.isEmpty) matchingDocs = allDoctors;
    }

    // Si NO hay doctores registrados con esa especialidad específica:
    if (!isGeneralRequest && matchingDocs.isEmpty) {
      return {
        'especialidad': specialty,
        'fecha_inicio': dateStr,
        'fecha_fin': dateStr,
        'mensaje_respuesta':
            'En este momento no contamos con doctores especialistas en **$specialty** registrados en la plataforma.',
        'doctors': <Map<String, dynamic>>[],
      };
    }

    // 5. Consultar disponibilidad y turnos libres para cada doctor
    final List<Map<String, dynamic>> doctorSlots = [];

    for (final doc in matchingDocs) {
      final docId = doc['id'];
      if (docId == null) continue;

      try {
        final availRes = await ApiClient.get('/doctors/$docId/availability');
        if (availRes.statusCode == 200) {
          final List<dynamic> availList = jsonDecode(availRes.body);

          // Buscar disponibilidad para la fecha deseada
          dynamic matchedDay = availList.firstWhere(
            (item) => item['date'] == dateStr,
            orElse: () => null,
          );

          // Si no hay exactamente ese día, buscar la fecha disponible más cercana posterior
          if (matchedDay == null) {
            final futureDays = availList.where((item) {
              final d = item['date']?.toString() ?? '';
              return d.compareTo(now.toIso8601String().substring(0, 10)) >= 0;
            }).toList();
            futureDays
                .sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));
            if (futureDays.isNotEmpty) {
              matchedDay = futureDays.first;
            }
          }

          if (matchedDay != null) {
            final slots = matchedDay['slots'] as List<dynamic>? ?? [];
            final freeSlots =
                slots.where((s) => s['available'] == true).toList();

            if (freeSlots.isNotEmpty) {
              final firstSlot = freeSlots.first;
              final dayDateStr = matchedDay['date']?.toString() ?? dateStr;
              final dayDate = DateTime.tryParse(dayDateStr) ?? targetDate;

              final prefix = (doc['gender'] == 'Femenino' ||
                      doc['gender'] == 'Femenina')
                  ? 'Dra.'
                  : 'Dr.';
              final name =
                  '$prefix ${doc['first_name'] ?? ''} ${doc['last_name'] ?? ''}'
                      .trim();
              final fee =
                  (doc['consultation_fee'] as num?)?.toDouble() ?? 50.0;
              final feeBcv = (fee * bcvRate).toStringAsFixed(2);

              const months = [
                'Ene',
                'Feb',
                'Mar',
                'Abr',
                'May',
                'Jun',
                'Jul',
                'Ago',
                'Sep',
                'Oct',
                'Nov',
                'Dic'
              ];
              const daysOfWeek = [
                'Lun',
                'Mar',
                'Mié',
                'Jue',
                'Vie',
                'Sáb',
                'Dom'
              ];
              final dateDisplay =
                  '${daysOfWeek[dayDate.weekday - 1]} ${dayDate.day} ${months[dayDate.month - 1]}';

              final docSpecs = (doc['specialties'] as List<dynamic>? ?? [])
                  .map((s) => s.toString())
                  .toList();
              final displaySpec = docSpecs.firstWhere(
                (s) =>
                    normalizeText(s).contains(normSpec) ||
                    normSpec.contains(normalizeText(s)),
                orElse: () =>
                    docSpecs.isNotEmpty ? docSpecs.first : specialty,
              );

              doctorSlots.add({
                'doctor_id': docId,
                'doctor_name': name.isEmpty ? 'Doctor' : name,
                'specialty': displaySpec,
                'avatar_url': doc['avatar_url'],
                'date': dayDateStr,
                'date_display': dateDisplay,
                'time_block': firstSlot['time_block']?.toString() ??
                    matchedDay['start_time'] ??
                    '10:00 AM',
                'turn_number': firstSlot['turn_number'] ?? 1,
                'available_slots_count': freeSlots.length,
                'price_usd': fee.toStringAsFixed(0),
                'price_bcv': feeBcv,
                'bcv_rate': bcvRate,
                'clinic_name': doc['clinic_name'] ?? 'Consultorio Privado',
                'location': doc['state'] ?? 'Caracas',
                'raw_doctor': doc,
              });
            }
          }
        }
      } catch (_) {}

      if (doctorSlots.length >= 4) break;
    }

    String answer;
    if (doctorSlots.isNotEmpty) {
      final exactMatch = doctorSlots.any((d) => d['date'] == dateStr);
      if (exactMatch) {
        answer =
            '¡Excelente! He encontrado turnos disponibles en **$specialty** para el **$dateStr**. Puedes tocar **"Agendar"** en la tarjeta para ver su perfil y confirmar tu turno:';
      } else {
        answer =
            'Para el **$dateStr** no encontré cupos directos en **$specialty**, pero aquí tienes las opciones más próximas con especialistas en esa área:';
      }
    } else {
      if (!isGeneralRequest) {
        answer =
            'En este momento los especialistas en **$specialty** no tienen turnos libres registrados para esa fecha.';
      } else {
        answer =
            'Consulté a nuestros médicos, pero en este momento no tienen turnos libres registrados para esa fecha. ¿Te gustaría consultar para otro día?';
      }
    }

    return {
      'especialidad': specialty,
      'fecha_inicio': dateStr,
      'fecha_fin': dateStr,
      'mensaje_respuesta': answer,
      'doctors': doctorSlots,
    };
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _oneClickBook(dynamic doctorData) async {
    HapticFeedback.mediumImpact();
    final doctorId = doctorData['doctor_id'] is int
        ? doctorData['doctor_id'] as int
        : int.tryParse(doctorData['doctor_id']?.toString() ?? '');
    final dateStr = doctorData['date']?.toString();
    final turnNumber = doctorData['turn_number'] is int
        ? doctorData['turn_number'] as int
        : int.tryParse(doctorData['turn_number']?.toString() ?? '');

    DateTime? targetDate;
    if (dateStr != null) {
      try {
        targetDate = DateTime.parse(dateStr);
      } catch (_) {}
    }

    // Usar el objeto doctor completo de la base de datos si está presente
    Map<String, dynamic> doctorMap = {};
    if (doctorData is Map<String, dynamic> &&
        doctorData.containsKey('raw_doctor') &&
        doctorData['raw_doctor'] is Map) {
      doctorMap = Map<String, dynamic>.from(doctorData['raw_doctor']);
    } else {
      doctorMap = {
        'id': doctorId,
        'first_name': doctorData['doctor_name'],
        'last_name': '',
        'specialties': [doctorData['specialty']],
        'avatar_url': doctorData['avatar_url'],
        'consultation_fee':
            double.tryParse(doctorData['price_usd']?.toString() ?? '50') ??
                50.0,
        'clinic_info': doctorData['clinic_name'],
        'state': doctorData['location'],
      };
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorProfileScreen(
          doctor: doctorMap,
          initialSelectedDate: targetDate,
          initialTurnNumber: turnNumber,
        ),
      ),
    );

    widget.onCitaAgendada?.call();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF003893); // Azul rey del logo
    const brightCyan = Color(0xFF00B4D8); // Cian brillante del logo
    const darkNavy = Color(0xFF0B2545);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: brightCyan.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: brightCyan.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Encabezado interactivo con la mascota Click ---
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue,
                  const Color(0xFF004CB3),
                  brightCyan.withValues(alpha: 0.85),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Row(
              children: [
                // Mascota Click con animación flotante
                AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: brightCyan.withValues(alpha: 0.6),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/click_mascot.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: brightCyan,
                          child: const Icon(Icons.smart_toy_rounded,
                              color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Título y estado
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Click',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Asistente IA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Agenda tus citas médicas al instante',
                        style: TextStyle(
                          color: Color(0xFFE0F2FE),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- Historial del Chat ---
          Container(
            constraints: const BoxConstraints(minHeight: 180, maxHeight: 380),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: ListView.separated(
              controller: _scrollController,
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildLoadingBubble(brightCyan);
                }
                final msg = _messages[index];
                return msg.isUser
                    ? _buildUserBubble(msg, primaryBlue)
                    : _buildAssistantBubble(msg, primaryBlue, brightCyan);
              },
            ),
          ),

          // --- Sugerencias Rápidas ---
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _suggestions.map((sug) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: const Color(0xFFF0F9FF),
                      surfaceTintColor: Colors.transparent,
                      side: BorderSide(
                        color: brightCyan.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      label: Text(
                        sug,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                      onPressed: () => _sendMessage(sug),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // --- Barra de entrada de texto interactiva ---
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Container(
              key: inputContainerKey,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: brightCyan.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: brightCyan.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('click_assistant_input_field'),
                      controller: _textController,
                      focusNode: inputFocusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: darkNavy,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText:
                            'Ej: Quiero una cita con un odontólogo este martes',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Botón Enviar con gradiente
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primaryBlue, brightCyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: brightCyan.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                      onPressed: () => _sendMessage(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(ClickMessage msg, Color primaryBlue) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: primaryBlue,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(
      ClickMessage msg, Color primaryBlue, Color brightCyan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: brightCyan, width: 1.5),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/click_mascot.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.smart_toy_rounded,
                      color: Color(0xFF003893),
                      size: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B2545).withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Tarjetas horizontales de doctores disponibles
        if (msg.doctors.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: msg.doctors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, dIdx) {
                  final doc = msg.doctors[dIdx];
                  return _buildDoctorCard(doc, primaryBlue, brightCyan);
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDoctorCard(
      dynamic doc, Color primaryBlue, Color brightCyan) {
    final name = doc['doctor_name']?.toString() ?? 'Doctor';
    final spec = doc['specialty']?.toString() ?? 'Especialista';
    final dateDisplay = doc['date_display']?.toString() ?? '';
    final timeBlock = doc['time_block']?.toString() ?? '';
    final turn = doc['turn_number']?.toString() ?? '1';
    final priceUsd = doc['price_usd']?.toString() ?? '50';
    final priceBcv = doc['price_bcv']?.toString() ?? '';
    final avatar = doc['avatar_url']?.toString();

    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: brightCyan.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor avatar y nombre
          Row(
            children: [
              ProfileAvatar(
                imageUrl: avatar,
                size: 40,
                fallbackRole: 'doctor',
                borderWidth: 0,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      spec,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0284C7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Badge de Día y Horario
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded,
                    color: Color(0xFF16A34A), size: 14),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '$dateDisplay · $timeBlock',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ),
                Text(
                  'T#$turn',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Precios USD / BCV
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$$priceUsd USD',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (priceBcv.isNotEmpty)
                      Text(
                        'Bs. $priceBcv',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Botón One-Click Booking
              ElevatedButton(
                onPressed: () => _oneClickBook(doc),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  minimumSize: const Size(80, 32),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('Agendar',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble(Color brightCyan) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: brightCyan.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2545).withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: brightCyan,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Buscando especialistas disponibles...',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


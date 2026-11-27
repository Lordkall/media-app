import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/medication_reminders.dart';
import 'settings_ui.dart';

String _formatTime12h(int hour24, int minute) {
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final h12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
}

class MedicationRemindersCard extends StatefulWidget {
  const MedicationRemindersCard({super.key});

  @override
  State<MedicationRemindersCard> createState() =>
      _MedicationRemindersCardState();
}

class _MedicationRemindersCardState extends State<MedicationRemindersCard>
    with WidgetsBindingObserver {
  static const _lockScreenTestedKey = 'medication_lockscreen_tested_v1';
  bool _busy = false;
  bool _lockScreenTested = false;
  bool _overlayAllowed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLockScreenTested();
    _refreshOverlayPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshOverlayPermission();
    }
  }

  Future<void> _refreshOverlayPermission() async {
    final allowed = await MedicationReminderService.canDrawOverlays();
    if (mounted && allowed != _overlayAllowed) {
      setState(() => _overlayAllowed = allowed);
    }
  }

  Future<void> _loadLockScreenTested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _lockScreenTested = prefs.getBool(_lockScreenTestedKey) ?? false;
      });
    } catch (_) {}
  }

  Future<void> _markLockScreenTested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lockScreenTestedKey, true);
      if (mounted) setState(() => _lockScreenTested = true);
    } catch (_) {}
  }

  Future<void> _edit([MedicationReminder? reminder]) async {
    final updated = await showDialog<MedicationReminder>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _MedicationEditor(reminder: reminder),
    );
    if (updated != null && mounted) await _save(updated);
  }

  Future<void> _save(MedicationReminder item, {bool remove = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    var savedOk = false;
    try {
      await MedicationReminderService.save(item, remove: remove);
      savedOk = true;
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message.toString()
          : 'No se pudieron guardar los recordatorios.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (savedOk &&
        mounted &&
        !remove &&
        item.enabled &&
        item.alarmMode &&
        defaultTargetPlatform == TargetPlatform.android &&
        !_lockScreenTested) {
      await _promptFirstTimeLockScreenTest();
    }
  }

  Future<void> _promptFirstTimeLockScreenTest() async {
    final shouldTest = await _showLockScreenDialog(firstTimeGuide: true);
    if (shouldTest == true && mounted) {
      await _executeLockScreenTest();
    }
  }

  Future<void> _delete(MedicationReminder item) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Eliminar recordatorio',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Se cancelarán los avisos de ${item.name}.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Cancelar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Eliminar',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) await _save(item, remove: true);
  }

  Future<void> _requestExactAlarms() async {
    try {
      await MedicationReminderService.requestExactAlarms();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Revisa el permiso de alarmas en Ajustes.')),
      );
    }
  }

  Future<void> _requestFullScreen() async {
    try {
      await MedicationReminderService.requestFullScreen();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Revisa los permisos de Salud Now en Ajustes.')),
      );
    }
  }

  Future<bool?> _showLockScreenDialog({bool firstTimeGuide = false}) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2545).withValues(alpha: 0.25),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF003893), Color(0xFF0077B6)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.phonelink_lock_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          firstTimeGuide
                              ? 'Activa el aviso sobre pantalla bloqueada'
                              : 'Probar con la pantalla bloqueada',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (firstTimeGuide) ...[
                        const Text(
                          '¡Recordatorio guardado! Para asegurar que suene y aparezca encima de la pantalla bloqueada, realiza esta prueba rápida una única vez:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _stepItem('1', 'Toca "Programar prueba" (sonará en 15 segundos).'),
                      const SizedBox(height: 8),
                      _stepItem('2', 'Bloquea inmediatamente la pantalla de tu teléfono.'),
                      const SizedBox(height: 8),
                      _stepItem(
                        '3',
                        'Si el teléfono te pide mostrar Salud Now sobre la pantalla de bloqueo, toca "Permitir".',
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_user_rounded,
                                size: 18, color: Color(0xFF059669)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Al darle Permitir una vez ya queda guardado para futuras alarmas. Esta prueba no cambia tus horarios.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF065F46),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogCtx, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  side: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    firstTimeGuide ? 'Más tarde' : 'Cancelar',
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 46,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0056B3),
                                      Color(0xFF0A3D78)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, true),
                                  icon: const Icon(Icons.alarm_on_rounded,
                                      size: 18),
                                  label: const Text(
                                    'Programar prueba',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    surfaceTintColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepItem(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE0EAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            num,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0056B3),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _tryLockScreen() async {
    final confirmed = await _showLockScreenDialog(firstTimeGuide: false);
    if (confirmed != true || !mounted) return;
    await _executeLockScreenTest();
  }

  Future<void> _executeLockScreenTest() async {
    setState(() => _busy = true);
    try {
      final result = await MedicationReminderService.scheduleScreenTest();
      if (!mounted) return;
      if (result == 'fullScreen') {
        await _requestFullScreen();
        return;
      }
      if (result == 'scheduled') {
        await _markLockScreenTested();
        if (!mounted) return;
      }
      final message = switch (result) {
        'scheduled' =>
          'Bloquea el teléfono. El aviso de prueba sonará en unos segundos.',
        'approximate' =>
          'Permite las alarmas exactas y vuelve a iniciar la prueba.',
        'disabled' => 'Activa las notificaciones de Salud Now en Ajustes.',
        _ => 'No se pudo programar la prueba.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo programar la prueba.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final android = defaultTargetPlatform == TargetPlatform.android;
    return SettingsCard(
      child: ValueListenableBuilder<List<MedicationReminder>>(
        valueListenable: MedicationReminderService.reminders,
        builder: (context, items, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionHeader(
              icon: Icons.medication_rounded,
              iconColor: const Color(0xFF0056B3),
              iconBg: const Color(0xFFE0EAFC),
              title: 'Recordatorios de medicamentos',
              subtitle: android
                  ? 'Avisos con sonido y vibración según los ajustes del teléfono.'
                  : 'Avisos con sonido según los ajustes del iPhone.',
            ),
            ValueListenableBuilder<String?>(
              valueListenable: MedicationReminderService.status,
              builder: (context, status, _) {
                if (!items.any((item) => item.enabled)) {
                  return const SizedBox.shrink();
                }
                final message = switch (status) {
                  'approximate' =>
                    'Sin el permiso de alarmas exactas, los avisos pueden retrasarse.',
                  'disabled' =>
                    'Activa las notificaciones de Salud Now en Ajustes para recibir los avisos.',
                  'limited' =>
                    'Algunos avisos de iPhone se programan con antelación limitada. Vuelve a abrir Salud Now con regularidad para renovarlos.',
                  'alarmFallback' =>
                    'Algunos avisos se enviarán como notificaciones. Revisa el permiso de alarmas en Ajustes.',
                  'capacity' =>
                    'Hay demasiados avisos programados en este iPhone. Pausa algunos para liberar espacio.',
                  _ => null,
                };
                if (message == null) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (status == 'approximate') ...[
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _requestExactAlarms,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text(
                            'Permitir alarmas exactas',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            if (android &&
                items.any((item) => item.enabled && item.alarmMode))
              ValueListenableBuilder<bool>(
                valueListenable: MedicationReminderService.fullScreenAllowed,
                builder: (context, allowed, _) => allowed
                    ? const SizedBox.shrink()
                    : Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.fullscreen_rounded,
                                color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Permite mostrar alarmas en pantalla completa.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _requestFullScreen,
                              child: const Text(
                                'Permitir',
                                style: TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            if (android &&
                items.any((item) => item.enabled && item.alarmMode) &&
                !_overlayAllowed)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.layers_outlined,
                        color: Color(0xFFD97706), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Permite mostrar sobre otras apps para que la alarma aparezca en pantalla mientras usas el teléfono.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await MedicationReminderService.requestDrawOverlays();
                        await _refreshOverlayPermission();
                      },
                      child: const Text(
                        'Permitir',
                        style: TextStyle(
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            if (android && items.any((item) => item.enabled && item.alarmMode))
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: InkWell(
                  onTap: _busy ? null : _tryLockScreen,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phonelink_lock_rounded,
                            color: Color(0xFF0056B3), size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Probar con el teléfono bloqueado',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0B2545),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _lockScreenTested
                                ? const Color(0xFF059669)
                                : const Color(0xFF0056B3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _lockScreenTested ? 'Verificado' : 'Probar',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (items.isNotEmpty) const SizedBox(height: 14),
            for (final item in items)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: item.enabled
                      ? const Color(0xFFF8FAFC)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item.enabled && item.alarmMode
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  onTap: _busy ? null : () => _edit(item),
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: !item.enabled
                          ? const Color(0xFFE2E8F0)
                          : item.alarmMode
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFE0EAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.alarmMode
                          ? Icons.alarm_rounded
                          : Icons.notifications_active_outlined,
                      size: 20,
                      color: !item.enabled
                          ? const Color(0xFF64748B)
                          : item.alarmMode
                              ? const Color(0xFF059669)
                              : const Color(0xFF0056B3),
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: item.enabled
                          ? const Color(0xFF0B2545)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${_formatTime12h(item.hour, item.minute)} · Cada ${item.intervalHours} h',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        if (item.alarmMode)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Alarma',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (!item.enabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF94A3B8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Pausado',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    enabled: !_busy,
                    tooltip: 'Opciones para ${item.name}',
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Color(0xFF475569)),
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          _edit(item);
                        case 'toggle':
                          _save(item.withEnabled(!item.enabled));
                        case 'delete':
                          _delete(item);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 18, color: Color(0xFF0056B3)),
                            SizedBox(width: 10),
                            Text('Editar',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              item.enabled
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 18,
                              color: item.enabled
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF059669),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              item.enabled ? 'Pausar' : 'Activar',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 18, color: Color(0xFFEF4444)),
                            SizedBox(width: 10),
                            Text('Eliminar',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFEF4444))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _edit(),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  foregroundColor: const Color(0xFF0056B3),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add_alarm_rounded),
                label: const Text(
                  'Añadir recordatorio',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationEditor extends StatefulWidget {
  const _MedicationEditor({required this.reminder});

  final MedicationReminder? reminder;

  @override
  State<_MedicationEditor> createState() => _MedicationEditorState();
}

class _MedicationEditorState extends State<_MedicationEditor> {
  static const _intervalPresets = [4, 6, 8, 12, 24];

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.reminder?.name);
  late final _interval = TextEditingController(
    text: (widget.reminder?.intervalHours ?? 24).toString(),
  );
  late bool _customInterval = widget.reminder != null &&
      !_intervalPresets.contains(widget.reminder!.intervalHours);
  late bool _alarmMode = widget.reminder?.alarmMode ?? false;
  late TimeOfDay _time = widget.reminder == null
      ? TimeOfDay.fromDateTime(
          DateTime.now().add(const Duration(hours: 1)),
        ).replacing(minute: 0)
      : TimeOfDay(hour: widget.reminder!.hour, minute: widget.reminder!.minute);

  @override
  void dispose() {
    _name.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _pickDigitalTime() async {
    final picked = await showDialog<TimeOfDay>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _DigitalAmPmTimePickerDialog(initialTime: _time),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final existing = widget.reminder;
    final now = DateTime.now();
    var first =
        DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
    if (!first.isAfter(now)) {
      first =
          DateTime(now.year, now.month, now.day + 1, _time.hour, _time.minute);
    }
    final interval = int.parse(_interval.text.trim());
    final unchangedSchedule = existing != null &&
        existing.hour == _time.hour &&
        existing.minute == _time.minute &&
        existing.intervalHours == interval;
    final ids = MedicationReminderService.reminders.value
        .map((item) => item.id)
        .toSet();
    var id = now.millisecondsSinceEpoch % 0x7fffffff;
    while (ids.contains(id)) {
      id = (id + 1) % 0x7fffffff;
    }
    Navigator.pop(
      context,
      MedicationReminder(
        id: existing?.id ?? id,
        name: _name.text.trim(),
        hour: _time.hour,
        minute: _time.minute,
        intervalHours: interval,
        firstAt:
            unchangedSchedule ? existing.firstAt : first.millisecondsSinceEpoch,
        enabled: existing?.enabled ?? true,
        alarmMode: _alarmMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentHours = int.tryParse(_interval.text.trim());
    final android = defaultTargetPlatform == TargetPlatform.android;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B2545).withValues(alpha: 0.25),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF003893), Color(0xFF0077B6)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.alarm_add_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.reminder == null
                                ? 'Añadir recordatorio'
                                : 'Editar recordatorio',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _name,
                          maxLength: 80,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: settingsInputDecoration(
                            label: 'Nombre del medicamento',
                            icon: Icons.medication_outlined,
                          ),
                          validator: (text) => (text ?? '').trim().isEmpty
                              ? 'Escribe el nombre del medicamento.'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _pickDigitalTime,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFBAE6FD)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    color: Color(0xFF0056B3), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Hora de inicio',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatTime12h(_time.hour, _time.minute),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0B2545),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0056B3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Cambiar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Repetir cada ciertas horas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0B2545),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final h in _intervalPresets)
                              ChoiceChip(
                                label: Text('Cada $h h'),
                                selected: !_customInterval && currentHours == h,
                                selectedColor: const Color(0xFF0056B3),
                                backgroundColor: const Color(0xFFF1F5F9),
                                side: BorderSide(
                                  color: !_customInterval && currentHours == h
                                      ? const Color(0xFF0056B3)
                                      : const Color(0xFFE2E8F0),
                                ),
                                labelStyle: TextStyle(
                                  color: !_customInterval && currentHours == h
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(() {
                                  _customInterval = false;
                                  _interval.text = '$h';
                                }),
                              ),
                            ChoiceChip(
                              label: const Text('Otro'),
                              selected: _customInterval,
                              selectedColor: const Color(0xFF0056B3),
                              backgroundColor: const Color(0xFFF1F5F9),
                              side: BorderSide(
                                color: _customInterval
                                    ? const Color(0xFF0056B3)
                                    : const Color(0xFFE2E8F0),
                              ),
                              labelStyle: TextStyle(
                                color: _customInterval
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              onSelected: (_) =>
                                  setState(() => _customInterval = true),
                            ),
                          ],
                        ),
                        if (_customInterval) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _interval,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: settingsInputDecoration(
                              label: 'Repetir cada',
                              icon: Icons.repeat_rounded,
                              suffixBadge: 'horas',
                            ),
                            validator: (text) {
                              final value = int.tryParse(text?.trim() ?? '');
                              return value == null ||
                                      value < 1 ||
                                      value > 0x7fffffff
                                  ? 'Escribe un número entero de horas válido.'
                                  : null;
                            },
                          ),
                        ],
                        if (MedicationReminderService.alarmModeAvailable) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _alarmMode
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _alarmMode
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _alarmMode
                                        ? const Color(0xFFD1FAE5)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_rounded,
                                    color: _alarmMode
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF64748B),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Modo Alarma',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0B2545),
                                        ),
                                      ),
                                      Text(
                                        android
                                            ? 'Repite el sonido hasta 1 minuto.'
                                            : 'Muestra una alarma de iPhone con Detener y Posponer.',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  activeThumbColor: const Color(0xFF059669),
                                  value: _alarmMode,
                                  onChanged: (value) =>
                                      setState(() => _alarmMode = value),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  side: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                ),
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 46,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0056B3),
                                        Color(0xFF0A3D78)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _submit,
                                    icon: const Icon(Icons.check_rounded,
                                        size: 18),
                                    label: const Text(
                                      'Guardar',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      surfaceTintColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reloj exclusivamente digital en formato de 12 horas (AM / PM) con estilo Salud Now.
class _DigitalAmPmTimePickerDialog extends StatefulWidget {
  const _DigitalAmPmTimePickerDialog({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_DigitalAmPmTimePickerDialog> createState() =>
      _DigitalAmPmTimePickerDialogState();
}

class _DigitalAmPmTimePickerDialogState
    extends State<_DigitalAmPmTimePickerDialog> {
  late int _hour12;
  late int _minute;
  late bool _isPm;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minCtrl;

  @override
  void initState() {
    super.initState();
    final rawH = widget.initialTime.hour;
    _isPm = rawH >= 12;
    _hour12 = rawH % 12 == 0 ? 12 : rawH % 12;
    _minute = widget.initialTime.minute;
    _hourCtrl = TextEditingController(text: _hour12.toString().padLeft(2, '0'));
    _minCtrl = TextEditingController(text: _minute.toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _hourCtrl.text = _hour12.toString().padLeft(2, '0');
    _hourCtrl.selection =
        TextSelection.collapsed(offset: _hourCtrl.text.length);
    _minCtrl.text = _minute.toString().padLeft(2, '0');
    _minCtrl.selection = TextSelection.collapsed(offset: _minCtrl.text.length);
  }

  void _stepHour(int delta) {
    setState(() {
      var next = _hour12 + delta;
      if (next > 12) next = 1;
      if (next < 1) next = 12;
      _hour12 = next;
      _syncControllers();
    });
  }

  void _stepMinute(int delta) {
    setState(() {
      _minute = (_minute + delta) % 60;
      if (_minute < 0) _minute += 60;
      _syncControllers();
    });
  }

  TimeOfDay _toTimeOfDay() {
    final typedH = int.tryParse(_hourCtrl.text.trim());
    final typedM = int.tryParse(_minCtrl.text.trim());
    final h12 = (typedH != null && typedH >= 1 && typedH <= 12)
        ? typedH
        : _hour12;
    final min = (typedM != null && typedM >= 0 && typedM <= 59)
        ? typedM
        : _minute;
    final h24 = _isPm ? (h12 == 12 ? 12 : h12 + 12) : (h12 == 12 ? 0 : h12);
    return TimeOfDay(hour: h24, minute: min);
  }

  Widget _digitBox({
    required TextEditingController controller,
    required String label,
    required VoidCallback onInc,
    required VoidCallback onDec,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onInc,
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFEFF6FF),
            foregroundColor: const Color(0xFF0056B3),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 82,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0B2545),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF0F9FF),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF0056B3), width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        IconButton(
          onPressed: onDec,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFEFF6FF),
            foregroundColor: const Color(0xFF0056B3),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _toTimeOfDay();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B2545).withValues(alpha: 0.25),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF003893), Color(0xFF0077B6)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.access_time_filled_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Seleccionar hora',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _formatTime12h(preview.hour, preview.minute),
                              style: const TextStyle(
                                color: Color(0xFFBAE6FD),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _digitBox(
                            controller: _hourCtrl,
                            label: 'Hora (1–12)',
                            onInc: () => _stepHour(1),
                            onDec: () => _stepHour(-1),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null &&
                                  parsed >= 1 &&
                                  parsed <= 12) {
                                setState(() => _hour12 = parsed);
                              }
                            },
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(10, 0, 10, 18),
                            child: Text(
                              ':',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0056B3),
                              ),
                            ),
                          ),
                          _digitBox(
                            controller: _minCtrl,
                            label: 'Minuto',
                            onInc: () => _stepMinute(5),
                            onDec: () => _stepMinute(-5),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null &&
                                  parsed >= 0 &&
                                  parsed <= 59) {
                                setState(() => _minute = parsed);
                              }
                            },
                          ),
                          const SizedBox(width: 14),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _periodButton('AM', !_isPm, () {
                                setState(() => _isPm = false);
                              }),
                              const SizedBox(height: 8),
                              _periodButton('PM', _isPm, () {
                                setState(() => _isPm = true);
                              }),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                side:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 46,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0056B3),
                                      Color(0xFF0A3D78)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      Navigator.pop(context, _toTimeOfDay()),
                                  icon: const Icon(Icons.check_rounded,
                                      size: 18),
                                  label: const Text(
                                    'Aceptar',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    surfaceTintColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _periodButton(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 54,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0056B3) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFF0056B3) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: active ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

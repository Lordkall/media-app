import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/medication_reminders.dart';

class MedicationRemindersCard extends StatefulWidget {
  const MedicationRemindersCard({super.key});

  @override
  State<MedicationRemindersCard> createState() =>
      _MedicationRemindersCardState();
}

class _MedicationRemindersCardState extends State<MedicationRemindersCard> {
  bool _busy = false;

  Future<void> _edit([MedicationReminder? reminder]) async {
    final updated = await showDialog<MedicationReminder>(
      context: context,
      builder: (_) => _MedicationEditor(reminder: reminder),
    );
    if (updated != null && mounted) await _save(updated);
  }

  Future<void> _save(MedicationReminder item, {bool remove = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await MedicationReminderService.save(item, remove: remove);
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
  }

  Future<void> _delete(MedicationReminder item) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar recordatorio'),
        content: Text('Se cancelarán los avisos de ${item.name}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
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

  Future<void> _tryLockScreen() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Probar con la pantalla bloqueada'),
        content: const Text(
          'Al programar la prueba, bloquea el teléfono. '
          'Si el teléfono te pide mostrar Salud Now sobre la pantalla de bloqueo, toca Permitir. '
          'Este aviso es solo una prueba y no cambia tus horarios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Programar prueba'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await MedicationReminderService.scheduleScreenTest();
      if (!mounted) return;
      if (result == 'fullScreen') {
        await _requestFullScreen();
        return;
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<List<MedicationReminder>>(
          valueListenable: MedicationReminderService.reminders,
          builder: (context, items, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recordatorios de medicamentos',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(android
                  ? 'Avisos con sonido y vibración según los ajustes del teléfono.'
                  : 'Avisos con sonido según los ajustes del iPhone.'),
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
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(message),
                      if (status == 'approximate')
                        TextButton(
                          onPressed: _requestExactAlarms,
                          child: const Text('Permitir alarmas exactas'),
                        ),
                    ],
                  );
                },
              ),
              if (android &&
                  items.any((item) => item.enabled && item.alarmMode))
                ValueListenableBuilder<bool>(
                  valueListenable: MedicationReminderService.fullScreenAllowed,
                  builder: (context, allowed, _) => allowed
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: _requestFullScreen,
                          child: const Text('Permitir pantalla completa'),
                        ),
                ),
              if (android &&
                  items.any((item) => item.enabled && item.alarmMode))
                TextButton.icon(
                  onPressed: _busy ? null : _tryLockScreen,
                  icon: const Icon(Icons.phonelink_lock_outlined),
                  label: const Text('Probar con el teléfono bloqueado'),
                ),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text(
                    '${TimeOfDay(hour: item.hour, minute: item.minute).format(context)}'
                    ' · Cada ${item.intervalHours} h'
                    '${item.alarmMode ? ' · Alarma' : ''}'
                    '${item.enabled ? '' : ' · Pausado'}',
                  ),
                  onTap: _busy ? null : () => _edit(item),
                  trailing: PopupMenuButton<String>(
                    enabled: !_busy,
                    tooltip: 'Opciones para ${item.name}',
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
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(item.enabled ? 'Pausar' : 'Activar'),
                      ),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _busy ? null : () => _edit(),
                icon: const Icon(Icons.add_alarm),
                label: const Text('Añadir recordatorio'),
              ),
            ],
          ),
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
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.reminder?.name);
  late final _interval = TextEditingController(
    text: (widget.reminder?.intervalHours ?? 24).toString(),
  );
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
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.reminder == null
            ? 'Añadir recordatorio'
            : 'Editar recordatorio'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  maxLength: 80,
                  decoration: const InputDecoration(
                      labelText: 'Nombre del medicamento'),
                  validator: (text) => (text ?? '').trim().isEmpty
                      ? 'Escribe el nombre del medicamento.'
                      : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Hora de inicio'),
                  subtitle: Text(_time.format(context)),
                  onTap: () async {
                    final time = await showTimePicker(
                        context: context, initialTime: _time);
                    if (time != null && mounted) setState(() => _time = time);
                  },
                ),
                TextFormField(
                  controller: _interval,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Repetir cada', suffixText: 'horas'),
                  validator: (text) {
                    final value = int.tryParse(text?.trim() ?? '');
                    return value == null || value < 1 || value > 0x7fffffff
                        ? 'Escribe un número entero de horas válido.'
                        : null;
                  },
                ),
                if (MedicationReminderService.alarmModeAvailable)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Modo Alarma'),
                    subtitle: Text(defaultTargetPlatform ==
                            TargetPlatform.android
                        ? 'Repite el sonido hasta 1 minuto.'
                        : 'Muestra una alarma de iPhone con Detener y Posponer.'),
                    value: _alarmMode,
                    onChanged: (value) => setState(() => _alarmMode = value),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('Guardar')),
        ],
      );
}

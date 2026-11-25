import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'api_client.dart';
import 'checkin_labels.dart';
import 'checkin_service.dart';

String _value(Map<String, dynamic> data, String key) =>
    data[key]?.toString() ?? '';

Map<String, dynamic> _object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _failure(BuildContext context, Object error) => error is ApiException
    ? error.message
    : checkinLabel(
        context,
        'Could not reach the server. Check your connection and try again.',
      );

String _stamp(BuildContext context, String value) {
  final time = DateTime.tryParse(value);
  if (time == null) return value;
  final local = time.toUtc().add(const Duration(hours: 5));
  final formatter = MaterialLocalizations.of(context);
  return '${formatter.formatShortDate(local)}, ${formatter.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
}

String _status(BuildContext context, String status) =>
    checkinLabel(context, switch (status) {
      'published' => 'Published',
      'draft' => 'Draft',
      'cancelled' => 'Cancelled',
      'completed' => 'Completed',
      'checked_in' => 'Checked in',
      'refunded' => 'Refunded',
      'valid' => 'Valid',
      'owner' => 'Owner',
      'manager' => 'Manager',
      'checkin_staff' => 'Check-in staff',
      _ => status,
    });

class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key, this.service});

  final CheckinService? service;

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  late final CheckinService _service = widget.service ?? CheckinService();
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await _service.assignedEvents();
      if (!mounted) return;
      setState(
        () => _events = events
            .where(
              (event) => [
                'owner',
                'manager',
                'checkin_staff',
              ].contains(event['my_role']),
            )
            .toList(),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _failure(context, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String label(String source) => checkinLabel(context, source);
    return Scaffold(
      appBar: AppBar(
        title: Text(label('Check-in')),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: label('Refresh'),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              label('Assigned events'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              label('Only events you are authorized to check in appear here.'),
            ),
            const SizedBox(height: 20),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) ...[
              _Message(text: _error!, error: true),
              OutlinedButton(onPressed: _load, child: Text(label('Try again'))),
            ],
            if (!_loading && _error == null && _events.isEmpty) ...[
              const Icon(Icons.event_available_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                label('No assigned events'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                label(
                  'Ask the organizer to add your account to the event team.',
                ),
                textAlign: TextAlign.center,
              ),
            ],
            for (final event in _events)
              Card(
                child: ListTile(
                  key: ValueKey('checkin-event-${event['id']}'),
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    _value(event, 'title'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      [
                        _stamp(context, _value(event, 'start_at')),
                        _value(event, 'venue_name'),
                        '${_status(context, _value(event, 'my_role'))} · ${_status(context, _value(event, 'status'))}',
                      ].where((value) => value.isNotEmpty).join('\n'),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          _CheckinEventPage(event: event, service: _service),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckinEventPage extends StatefulWidget {
  const _CheckinEventPage({required this.event, required this.service});

  final Map<String, dynamic> event;
  final CheckinService service;

  @override
  State<_CheckinEventPage> createState() => _CheckinEventPageState();
}

class _CheckinEventPageState extends State<_CheckinEventPage>
    with WidgetsBindingObserver {
  final _qr = TextEditingController();
  final _query = TextEditingController();
  final _ownAdmissions = <String, DateTime>{};
  MobileScannerController? _scanner;
  Animation<double>? _coveredAnimation;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _attendees = [];
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _busy = false;
  bool _camera = false;
  bool _uncertain = false;
  bool _recordsStale = false;
  String? _uncertainQr;
  String? _error;
  String? _notice;
  int _tab = 0;
  int _loadVersion = 0;

  String get _id => _value(widget.event, 'id');
  bool get _published => widget.event['status'] == 'published';
  bool get _writeEnabled =>
      _published && !_busy && !_uncertain && !_recordsStale && !_loading;
  String label(String source) => checkinLabel(context, source);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.secondaryAnimation;
    if (_coveredAnimation != animation) {
      _coveredAnimation?.removeStatusListener(_covered);
      _coveredAnimation = animation;
      animation?.addStatusListener(_covered);
    }
  }

  void _covered(AnimationStatus status) {
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.completed) {
      unawaited(_stopCamera());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coveredAnimation?.removeStatusListener(_covered);
    final scanner = _scanner;
    if (scanner != null) unawaited(scanner.dispose());
    _qr.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<bool> _refresh() async {
    final version = ++_loadVersion;
    if (mounted) setState(() => _loading = true);
    try {
      final values = await Future.wait<dynamic>([
        widget.service.stats(_id),
        widget.service.attendees(_id, query: _query.text.trim()),
        widget.service.history(_id),
      ]);
      if (!mounted || version != _loadVersion) return false;
      setState(() {
        _stats = _object(values[0]);
        _attendees = List<Map<String, dynamic>>.from(values[1] as List);
        _history = List<Map<String, dynamic>>.from(values[2] as List);
        _recordsStale = false;
        _error = null;
      });
      return true;
    } catch (error) {
      if (mounted && version == _loadVersion) {
        setState(() {
          _recordsStale = true;
          _error = _failure(context, error);
        });
      }
      return false;
    } finally {
      if (mounted && version == _loadVersion) setState(() => _loading = false);
    }
  }

  Future<void> _stopCamera() async {
    if (_camera && mounted) setState(() => _camera = false);
    try {
      await _scanner?.stop();
    } catch (_) {}
  }

  Future<void> _startCamera() async {
    if (!_writeEnabled) return;
    if (!kIsWeb &&
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform)) {
      setState(
        () => _error = label(
          'Camera scanning is not supported on this device. Use attendee search or enter the ticket QR text.',
        ),
      );
      return;
    }
    _scanner ??= MobileScannerController(
      autoStart: false,
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    setState(() {
      _camera = true;
      _result = null;
      _error = null;
      _notice = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_camera) return;
      try {
        await _scanner!.start();
        if (!mounted || !_camera) await _scanner!.stop();
      } catch (_) {
        if (mounted) {
          setState(() {
            _camera = false;
            _error = label(
              'Camera unavailable. Allow camera access in your device settings or use attendee search.',
            );
          });
        }
      }
    });
  }

  void _detected(BarcodeCapture capture) {
    if (!_camera || !_writeEnabled) return;
    for (final barcode in capture.barcodes) {
      final payload = barcode.rawValue;
      if (payload != null && payload.isNotEmpty) {
        unawaited(_submitQr(payload, admit: true));
        break;
      }
    }
  }

  bool _validateQr(String payload) {
    String? message;
    final scheme = Uri.tryParse(payload.trim())?.scheme.toLowerCase();
    if (payload.trim().isEmpty) {
      message = label('Enter the ticket QR text.');
    } else if (scheme == 'http' || scheme == 'https') {
      message = label(
        'This is a web or promotional link, not a ticket QR code. Ask for the attendee ticket.',
      );
    } else if (payload.length > 500) {
      message = label(
        'The QR text is too long. Use the issued ticket QR code.',
      );
    }
    if (message == null) return true;
    setState(() {
      _error = message;
      _result = null;
    });
    unawaited(_stopCamera());
    return false;
  }

  Future<void> _submitQr(String payload, {required bool admit}) async {
    if (!_writeEnabled || !_validateQr(payload)) return;
    await _perform(
      () => admit
          ? widget.service.scan(_id, payload)
          : widget.service.verify(_id, payload),
      writes: admit,
      qrPayload: payload,
    );
  }

  Future<void> _perform(
    Future<Map<String, dynamic>> Function() action, {
    required bool writes,
    String? qrPayload,
  }) async {
    if (_busy || _uncertain || !_published) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _result = null;
    });
    unawaited(_stopCamera());
    try {
      final result = await action();
      if (!mounted) return;
      final ticket = _object(result['ticket']);
      setState(() {
        _result = result;
        if (result['admitted'] == true &&
            result['result'] == 'valid' &&
            ticket['status'] == 'checked_in') {
          _ownAdmissions[_value(ticket, 'id')] =
              DateTime.tryParse(_value(ticket, 'checked_in_at')) ??
              DateTime.now();
        }
      });
      if (writes) await _refresh();
    } catch (error) {
      if (!mounted) return;
      final knownRejection =
          error is ApiException &&
          error.statusCode >= 400 &&
          error.statusCode < 500 &&
          error.statusCode != 408;
      setState(() {
        _error = _failure(context, error);
        if (writes && !knownRejection) {
          _uncertain = true;
          _uncertainQr = qrPayload;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reconcile() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await _refresh() || !mounted) return;
      Map<String, dynamic>? result;
      if (_uncertainQr != null) {
        result = await widget.service.verify(_id, _uncertainQr!);
      }
      if (!mounted) return;
      setState(() {
        _uncertain = false;
        _uncertainQr = null;
        _result = result;
        _notice = label(
          'Server records refreshed. Review the ticket status before another action.',
        );
      });
    } catch (error) {
      if (mounted) setState(() => _error = _failure(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _canUndo(String ticketId) {
    if (!_writeEnabled) return false;
    if (['owner', 'manager'].contains(widget.event['my_role'])) return true;
    final admittedAt = _ownAdmissions[ticketId];
    return admittedAt != null &&
        DateTime.now().difference(admittedAt) < const Duration(minutes: 10);
  }

  Future<void> _undo(String ticketId) async {
    if (!_canUndo(ticketId)) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _UndoReasonDialog(),
    );
    if (!mounted || reason == null || !_canUndo(ticketId)) return;
    await _perform(() async {
      await widget.service.undo(_id, ticketId, reason);
      _ownAdmissions.remove(ticketId);
      return <String, dynamic>{
        'admitted': false,
        'message': label(
          'Check-in undone. The server record has been updated.',
        ),
      };
    }, writes: true);
  }

  Widget _statistics() {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final pair in [
          ('Registered', 'registered'),
          ('Checked in', 'checked_in'),
          ('Remaining', 'remaining'),
        ])
          Container(
            constraints: const BoxConstraints(minWidth: 95),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _value(stats, pair.$2),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(label(pair.$1)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _resultCard() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();
    final ticket = _object(result['ticket']);
    final admitted =
        result['admitted'] == true &&
        result['result'] == 'valid' &&
        ticket['status'] == 'checked_in';
    final title = admitted
        ? 'Admission confirmed'
        : switch (result['result']) {
            'valid' => 'Valid ticket — not checked in',
            'already_used' => 'Already checked in',
            'cancelled' => 'Cancelled ticket',
            'refunded' => 'Refunded ticket',
            'wrong_event' => 'Wrong event',
            'invalid' => 'Invalid code',
            _ => 'Server result',
          };
    return Semantics(
      liveRegion: true,
      child: Card(
        key: const ValueKey('scan-result'),
        color: admitted
            ? const Color(0xffd8f2df)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    admitted
                        ? Icons.check_circle
                        : result['result'] == 'valid'
                        ? Icons.verified_outlined
                        : Icons.warning_amber,
                    color: admitted
                        ? Colors.green.shade800
                        : Colors.deepOrange.shade800,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label(title),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff17231a),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_value(result, 'message')),
              if (ticket.isNotEmpty) ...[
                const Divider(),
                Text(
                  _value(ticket, 'attendee_name'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(_value(ticket, 'ticket_type_name')),
                SelectableText(
                  '${label('Ticket reference')}: ${_value(ticket, 'id')}',
                ),
                if (_value(ticket, 'seat').isNotEmpty)
                  Text('${label('Seat')}: ${_value(ticket, 'seat')}'),
                if (_value(ticket, 'checked_in_at').isNotEmpty)
                  Text(
                    '${_stamp(context, _value(ticket, 'checked_in_at'))} UTC+05:00',
                  ),
                if (_value(ticket, 'checked_in_by_name').isNotEmpty)
                  Text(
                    '${label('Recorded by')}: ${_value(ticket, 'checked_in_by_name')}',
                  ),
                if (ticket['status'] == 'valid')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton(
                      onPressed: _writeEnabled
                          ? () => _perform(
                              () => widget.service.admit(
                                _id,
                                _value(ticket, 'id'),
                              ),
                              writes: true,
                            )
                          : null,
                      child: Text(label('Check in')),
                    ),
                  ),
                if (ticket['status'] == 'checked_in' &&
                    _canUndo(_value(ticket, 'id')))
                  TextButton(
                    onPressed: () => _undo(_value(ticket, 'id')),
                    child: Text(label('Undo check-in')),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _scanTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label(
          'An internet connection is required. Tickets are checked with the server before admission.',
        ),
      ),
      const SizedBox(height: 12),
      if (_camera && _scanner != null) ...[
        SizedBox(
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MobileScanner(
              controller: _scanner,
              useAppLifecycleState: false,
              onDetect: _detected,
              errorBuilder: (_, _) => ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      label(
                        'Camera unavailable. Allow camera access in your device settings or use attendee search.',
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _stopCamera,
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text(label('Stop camera')),
        ),
      ] else
        FilledButton.icon(
          key: const ValueKey('start-camera'),
          onPressed: _writeEnabled ? _startCamera : null,
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(
            label(_result == null ? 'Scan and admit' : 'Scan next ticket'),
          ),
        ),
      const SizedBox(height: 8),
      Text(
        label('A successful scan checks in this ticket immediately.'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 22),
      TextField(
        key: const ValueKey('qr-payload'),
        controller: _qr,
        enabled: !_busy && !_uncertain,
        minLines: 1,
        maxLines: 3,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: label('Ticket QR text'),
          hintText: label('Paste the exact text from a ticket QR code'),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: _writeEnabled
                ? () => _submitQr(_qr.text, admit: false)
                : null,
            child: Text(label('Verify only')),
          ),
          FilledButton(
            key: const ValueKey('submit-qr'),
            onPressed: _writeEnabled
                ? () => _submitQr(_qr.text, admit: true)
                : null,
            child: Text(label(_busy ? 'Checking…' : 'Check in')),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _resultCard(),
    ],
  );

  Widget _attendeeTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('attendee-search'),
        controller: _query,
        decoration: InputDecoration(
          labelText: label('Search by name, email or ticket reference'),
          suffixIcon: IconButton(
            tooltip: label('Search'),
            onPressed: _busy || _loading ? null : _refresh,
            icon: const Icon(Icons.search),
          ),
        ),
        onSubmitted: (_) {
          if (!_busy) unawaited(_refresh());
        },
      ),
      const SizedBox(height: 16),
      if (_attendees.isEmpty && !_loading) Text(label('No attendees found')),
      for (final attendee in _attendees)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _value(attendee, 'attendee_name'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(_value(attendee, 'attendee_email')),
                Text(
                  '${_value(attendee, 'ticket_type_name')} · ${_status(context, _value(attendee, 'status'))}',
                ),
                SelectableText(
                  _value(attendee, 'ticket_id'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_value(attendee, 'seat').isNotEmpty)
                  Text('${label('Seat')}: ${_value(attendee, 'seat')}'),
                if (_value(attendee, 'checked_in_at').isNotEmpty)
                  Text(
                    '${_stamp(context, _value(attendee, 'checked_in_at'))} UTC+05:00',
                  ),
                if (attendee['status'] == 'valid')
                  FilledButton(
                    onPressed: _writeEnabled
                        ? () => _perform(
                            () => widget.service.admit(
                              _id,
                              _value(attendee, 'ticket_id'),
                            ),
                            writes: true,
                          )
                        : null,
                    child: Text(label('Check in')),
                  ),
                if (attendee['status'] == 'checked_in' &&
                    _canUndo(_value(attendee, 'ticket_id')))
                  TextButton(
                    onPressed: () => _undo(_value(attendee, 'ticket_id')),
                    child: Text(label('Undo check-in')),
                  ),
              ],
            ),
          ),
        ),
      _resultCard(),
    ],
  );

  Widget _historyTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label(
          'Latest server records. Refresh to see activity from other devices.',
        ),
      ),
      const SizedBox(height: 16),
      if (_history.isEmpty && !_loading) Text(label('No check-in records yet')),
      for (final record in _history)
        Card(
          child: ListTile(
            leading: Icon(
              record['action'] == 'undo' ? Icons.undo : Icons.how_to_reg,
            ),
            title: Text(_value(record, 'attendee_name')),
            subtitle: Text(
              [
                '${label(record['action'] == 'undo' ? 'Undo' : 'Checked in')} · ${label(record['method'] == 'scan' ? 'Scan' : 'Manual')}',
                '${_stamp(context, _value(record, 'created_at'))} UTC+05:00',
                _value(record, 'performed_by_name'),
                _value(record, 'ticket_id'),
                _value(record, 'reason'),
              ].where((text) => text.isNotEmpty).join('\n'),
            ),
            isThreeLine: true,
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_value(widget.event, 'title')),
      actions: [
        IconButton(
          tooltip: label('Refresh'),
          onPressed: _busy || _loading
              ? null
              : _uncertain
              ? _reconcile
              : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${_status(context, _value(widget.event, 'my_role'))} · ${_status(context, _value(widget.event, 'status'))}',
        ),
        const SizedBox(height: 12),
        _statistics(),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
        if (!_published)
          _Message(
            text: label(
              'Check-in is available only while this event is published.',
            ),
          ),
        if (_uncertain) ...[
          _Message(text: label('Result unknown'), error: true),
          _Message(
            text: label(
              'The request may have reached the server. Do not admit the attendee based on this screen. Refresh server records before trying again.',
            ),
            error: true,
          ),
          FilledButton(
            onPressed: _busy ? null : _reconcile,
            child: Text(label('Reconcile server records')),
          ),
        ],
        if (_recordsStale)
          _Message(
            text: label(
              'Records could not be refreshed. Refresh before continuing.',
            ),
            error: true,
          ),
        if (_error != null) _Message(text: _error!, error: true),
        if (_notice != null) _Message(text: _notice!),
        if (widget.event['my_role'] == 'checkin_staff')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label(
                'Staff can undo only their own check-ins within 10 minutes. Ask a manager for older records.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in [
              'Scan',
              'Attendees',
              'History',
            ].asMap().entries)
              ChoiceChip(
                label: Text(label(entry.value)),
                selected: _tab == entry.key,
                onSelected: (_) {
                  unawaited(_stopCamera());
                  setState(() => _tab = entry.key);
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (_tab == 0)
          _scanTab()
        else if (_tab == 1)
          _attendeeTab()
        else
          _historyTab(),
        const SizedBox(height: 30),
      ],
    ),
  );
}

class _UndoReasonDialog extends StatefulWidget {
  const _UndoReasonDialog();

  @override
  State<_UndoReasonDialog> createState() => _UndoReasonDialogState();
}

class _UndoReasonDialogState extends State<_UndoReasonDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String label(String source) => checkinLabel(context, source);
    return AlertDialog(
      title: Text(label('Undo check-in')),
      content: Form(
        key: _form,
        child: TextFormField(
          key: const ValueKey('undo-reason'),
          controller: _reason,
          autofocus: true,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: label('Undo reason'),
            hintText: label('Explain why this check-in should be reversed'),
          ),
          validator: (value) => (value?.trim().length ?? 0) < 3
              ? label('Use 3 to 500 characters.')
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(label('Cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, _reason.text.trim());
            }
          },
          child: Text(label('Confirm undo')),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error
            ? const Color(0xffffe5de)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: error ? const Color(0xff8b2110) : null),
      ),
    ),
  );
}

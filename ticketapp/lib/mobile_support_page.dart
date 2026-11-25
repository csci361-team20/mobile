import 'package:flutter/material.dart';

import 'api_client.dart';
import 'mobile_operations_service.dart';
import 'mobile_support_labels.dart';

String _error(Object error, BuildContext context) => error is ApiException
    ? error.message
    : supportLabel(context, 'Request could not be completed.');

class MobileSupportPage extends StatefulWidget {
  final String? eventId;
  final String? orderId;
  final String? ticketId;
  final bool organizer;

  const MobileSupportPage({
    super.key,
    this.eventId,
    this.orderId,
    this.ticketId,
    this.organizer = false,
  });

  @override
  State<MobileSupportPage> createState() => _MobileSupportPageState();
}

class _MobileSupportPageState extends State<MobileSupportPage> {
  final _service = MobileOperationsService();
  List<Map<String, dynamic>> _cases = [];
  bool _loading = true;
  String? _failure;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final records = await _service.cases();
      if (mounted && request == _request) setState(() => _cases = records);
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _failure = _error(error, context));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _newCase() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _NewCasePage(
          service: _service,
          eventId: widget.eventId,
          orderId: widget.orderId,
          ticketId: widget.ticketId,
          organizer: widget.organizer,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _openCase(result);
  }

  Future<void> _openCase(Map<String, dynamic> record) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _CasePage(service: _service, initial: record),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    String t(String value) => supportLabel(context, value);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Support')),
        actions: [
          IconButton(
            tooltip: t('Refresh'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _newCase,
        icon: const Icon(Icons.add),
        label: Text(t('New request')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_failure != null) ...[
              Text(
                _failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(onPressed: _load, child: Text(t('Try again'))),
            ],
            if (!_loading && _failure == null && _cases.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t('No support cases yet.')),
              ),
            ..._cases.map(
              (record) => Card(
                child: ListTile(
                  title: Text(record['subject']?.toString() ?? ''),
                  subtitle: Text(
                    '${t(record['status']?.toString() ?? '')} · ${t(record['category']?.toString() ?? '')}${record['event_title'] == null ? '' : '\n${record['event_title']}'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openCase(record),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CasePage extends StatefulWidget {
  final MobileOperationsService service;
  final Map<String, dynamic> initial;
  const _CasePage({required this.service, required this.initial});

  @override
  State<_CasePage> createState() => _CasePageState();
}

class _CasePageState extends State<_CasePage> {
  late Map<String, dynamic> _case;
  final _reply = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _loaded = false;
  bool _replyUncertain = false;
  String? _failure;
  int _request = 0;
  String get _id => _case['id'].toString();

  @override
  void initState() {
    super.initState();
    _case = widget.initial;
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final record = await widget.service.caseDetail(_id);
      if (mounted && request == _request) {
        setState(() {
          _case = record;
          _loaded = true;
          _replyUncertain = false;
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _failure = _error(error, context));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _change(
    Future<Map<String, dynamic>> Function() action, {
    bool reply = false,
  }) async {
    if (_busy || _loading || !_loaded || (reply && _replyUncertain)) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final result = await action();
      if (!mounted) {
        return;
      }
      setState(() => _case = result);
      if (reply) _reply.clear();
    } catch (error) {
      if (mounted) {
        setState(() {
          _failure = _error(error, context);
          if (reply &&
              (error is! ApiException ||
                  error.statusCode == 0 ||
                  error.statusCode >= 500)) {
            _replyUncertain = true;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign() async {
    if (_busy || _loading || _case['can_manage'] != true) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final options = await widget.service.caseAssignees(_id);
      if (!mounted) return;
      final selected = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: Text(supportLabel(dialogContext, 'Assign case')),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: Text(supportLabel(dialogContext, 'Unassigned')),
            ),
            ...options.map(
              (option) => SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(dialogContext, option['user_id'].toString()),
                child: Text(option['full_name']?.toString() ?? ''),
              ),
            ),
          ],
        ),
      );
      if (!mounted || selected == null) return;
      final result = await widget.service.updateCase(_id, {
        'assignee_user_id': selected.isEmpty ? null : selected,
      });
      if (mounted) setState(() => _case = result);
    } catch (error) {
      if (mounted) setState(() => _failure = _error(error, context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _escalate() async {
    final form = GlobalKey<FormState>();
    var reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(supportLabel(dialogContext, 'Escalate to platform')),
        content: Form(
          key: form,
          child: TextFormField(
            maxLength: 500,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: supportLabel(dialogContext, 'Reason'),
            ),
            onChanged: (value) => reason = value.trim(),
            validator: (value) => (value?.trim().length ?? 0) < 3
                ? supportLabel(dialogContext, 'Use 3–500 characters.')
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(supportLabel(dialogContext, 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(supportLabel(dialogContext, 'Confirm')),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      await _change(() => widget.service.escalateCase(_id, reason));
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String value) => supportLabel(context, value);
    final messages = (_case['messages'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final history = (_case['history'] as List? ?? []).whereType<Map>().toList();
    final canManage = _loaded && _case['can_manage'] == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(_case['subject']?.toString() ?? t('Support')),
        actions: [
          IconButton(
            tooltip: t('Refresh'),
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading || _busy) const LinearProgressIndicator(),
          if (_failure != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_replyUncertain) ...[
            Text(
              t(
                'The request may have been saved. Refresh your cases before trying again.',
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _load,
              child: Text(t('Refresh')),
            ),
          ],
          Text(
            t(_case['status']?.toString() ?? ''),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_case['event_title'] != null)
            Text('${t('Event')}: ${_case['event_title']}'),
          if (_case['order_id'] != null)
            SelectableText('${t('Order')}: ${_case['order_id']}'),
          if (_case['ticket_id'] != null)
            SelectableText('${t('Ticket')}: ${_case['ticket_id']}'),
          if (_case['assignee_name'] != null)
            Text('${t('Assign case')}: ${_case['assignee_name']}'),
          if (_case['is_escalated'] == true) Text(t('Escalated')),
          if (canManage)
            Wrap(
              spacing: 8,
              children: [
                PopupMenuButton<String>(
                  enabled: !_loading && !_busy,
                  tooltip: t('Change status'),
                  onSelected: (value) => _change(
                    () => widget.service.updateCase(_id, {'status': value}),
                  ),
                  itemBuilder: (_) =>
                      [
                            'open',
                            'in_progress',
                            'waiting_for_customer',
                            'resolved',
                          ]
                          .map(
                            (value) => PopupMenuItem(
                              value: value,
                              child: Text(t(value)),
                            ),
                          )
                          .toList(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(t('Change status')),
                  ),
                ),
                TextButton(
                  onPressed: _loading || _busy ? null : _assign,
                  child: Text(t('Assign case')),
                ),
                if (_case['audience'] == 'attendee' &&
                    _case['is_escalated'] != true)
                  TextButton(
                    onPressed: _loading || _busy ? null : _escalate,
                    child: Text(t('Escalate to platform')),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          if (!_loading && _loaded && messages.isEmpty)
            Text(t('No messages yet.')),
          ...messages.map(
            (message) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${message['sender_name'] ?? ''} · ${t(message['from_staff'] == true ? 'Staff' : 'Customer')}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(message['body']?.toString() ?? ''),
                    const SizedBox(height: 6),
                    Text(_date(message['created_at'])),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reply,
            enabled: !_busy && !_loading && _loaded,
            minLines: 2,
            maxLines: 5,
            maxLength: 5000,
            decoration: InputDecoration(
              labelText: t('Reply'),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_case['status'] == 'resolved')
            Text(t('A reply reopens a resolved case.')),
          FilledButton(
            onPressed: _busy || _loading || !_loaded || _replyUncertain
                ? null
                : () {
                    final text = _reply.text.trim();
                    if (text.isEmpty || text.length > 5000) {
                      setState(() => _failure = t('Use 1–5000 characters.'));
                      return;
                    }
                    _change(() => widget.service.reply(_id, text), reply: true);
                  },
            child: Text(t(_busy ? 'Sending…' : 'Send reply')),
          ),
          if (history.isNotEmpty)
            ExpansionTile(
              title: Text(t('History')),
              children: history
                  .map(
                    (record) => ListTile(
                      title: Text(record['action']?.toString() ?? ''),
                      subtitle: Text(
                        '${record['actor_name'] ?? ''} · ${_date(record['created_at'])}',
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

String _date(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')
      ?.toUtc()
      .add(const Duration(hours: 5));
  if (date == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)} UTC+05:00';
}

class _NewCasePage extends StatefulWidget {
  final MobileOperationsService service;
  final String? eventId;
  final String? orderId;
  final String? ticketId;
  final bool organizer;
  const _NewCasePage({
    required this.service,
    this.eventId,
    this.orderId,
    this.ticketId,
    required this.organizer,
  });

  @override
  State<_NewCasePage> createState() => _NewCasePageState();
}

class _NewCasePageState extends State<_NewCasePage> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  bool _loading = false;
  bool _uncertain = false;
  bool _completed = false;
  bool _organizerReady = false;
  String? _failure;
  String? _contextChoice;
  late String _category;
  List<Map<String, String>> _contexts = [];
  bool get _givenContext =>
      widget.eventId != null ||
      widget.orderId != null ||
      widget.ticketId != null;

  @override
  void initState() {
    super.initState();
    _category = widget.organizer ? 'account' : 'event_information';
    _prepare();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (!widget.organizer && _givenContext) return;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      if (widget.organizer) {
        await widget.service.ownOrganizer();
        if (mounted) setState(() => _organizerReady = true);
      } else {
        final records = await Future.wait([
          widget.service.myOrders(),
          widget.service.publicEvents(),
        ]);
        final options = <Map<String, String>>[
          ...records[0].map(
            (record) => {
              'value': 'order:${record['id']}',
              'kind': 'Order',
              'title': record['event_title']?.toString() ?? '',
              'id': record['id'].toString(),
            },
          ),
          ...records[1].map(
            (record) => {
              'value': 'event:${record['id']}',
              'kind': 'Event',
              'title': record['title']?.toString() ?? '',
              'id': record['id'].toString(),
            },
          ),
        ];
        if (mounted) setState(() => _contexts = options);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _failure =
              widget.organizer &&
                  error is ApiException &&
                  error.statusCode == 404
              ? supportLabel(
                  context,
                  'Organizer support requires an organizer profile.',
                )
              : _error(error, context),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_busy ||
        _loading ||
        _uncertain ||
        _completed ||
        !_form.currentState!.validate()) {
      return;
    }
    if (!widget.organizer && !_givenContext && _contextChoice == null) return;
    final body = <String, dynamic>{
      'audience': widget.organizer ? 'organizer' : 'attendee',
      'category': _category,
      'subject': _subject.text.trim(),
      'message': _message.text.trim(),
      if (widget.eventId != null) 'event_id': widget.eventId,
      if (widget.orderId != null) 'order_id': widget.orderId,
      if (widget.ticketId != null) 'ticket_id': widget.ticketId,
    };
    if (!_givenContext && _contextChoice != null) {
      final parts = _contextChoice!.split(':');
      body['${parts.first}_id'] = parts.last;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final record = await widget.service.createCase(body);
      if (mounted) {
        setState(() => _completed = true);
        Navigator.of(context).pop(record);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _failure = _error(error, context);
          _uncertain =
              error is! ApiException ||
              error.statusCode == 0 ||
              error.statusCode >= 500;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final records = await widget.service.cases(scope: 'requested');
      if (!mounted) return;
      final reviewed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(supportLabel(dialogContext, 'Support')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: records
                  .map(
                    (record) => ListTile(
                      title: Text(record['subject']?.toString() ?? ''),
                      subtitle: Text(
                        '${record['id']} · ${supportLabel(dialogContext, record['status'].toString())}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(supportLabel(dialogContext, 'Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                supportLabel(dialogContext, 'I reviewed existing cases'),
              ),
            ),
          ],
        ),
      );
      if (mounted && reviewed == true) setState(() => _uncertain = false);
    } catch (error) {
      if (mounted) setState(() => _failure = _error(error, context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String value) => supportLabel(context, value);
    final categories = widget.organizer
        ? ['account', 'activation', 'payment', 'technical']
        : [
            'ticket_delivery',
            'payment',
            'refund',
            'seating',
            'event_information',
            'check_in',
            'account',
            'technical',
          ];
    return Scaffold(
      appBar: AppBar(title: Text(t('New request'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t(widget.organizer ? 'Organizer request' : 'Attendee request'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              t('Event, order and ticket details are attached when available.'),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_failure != null) ...[
              Text(
                _failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (!_busy && !_uncertain)
                TextButton(onPressed: _prepare, child: Text(t('Try again'))),
            ],
            if (_givenContext)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SelectableText(
                  '${t('Context')}: ${widget.ticketId ?? widget.orderId ?? widget.eventId}',
                ),
              ),
            if (!widget.organizer && !_givenContext && !_loading) ...[
              if (_contexts.isEmpty)
                Text(
                  t(
                    'Open an event, order or ticket page to include its context.',
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: _contextChoice,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: t('Choose an event or order'),
                ),
                items: _contexts
                    .map(
                      (record) => DropdownMenuItem(
                        value: record['value'],
                        child: Text(
                          '${t(record['kind']!)}: ${record['title']} · ${record['id']!.substring(0, 8)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _contextChoice = value),
                validator: (value) =>
                    value == null ? t('Choose an event or order') : null,
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: t('Category')),
              items: categories
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(t(value))),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subject,
              enabled: !_busy,
              maxLength: 200,
              decoration: InputDecoration(labelText: t('Subject')),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? t('Use 3–200 characters.')
                  : null,
            ),
            TextFormField(
              controller: _message,
              enabled: !_busy,
              maxLength: 5000,
              minLines: 4,
              maxLines: 9,
              decoration: InputDecoration(
                labelText: t('Message'),
                border: const OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? t('Use 1–5000 characters.')
                  : null,
            ),
            if (_uncertain) ...[
              Text(
                t(
                  'The request may have been saved. Refresh your cases before trying again.',
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _review,
                child: Text(t('Refresh cases before another attempt')),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  _busy ||
                      _loading ||
                      _uncertain ||
                      _completed ||
                      (widget.organizer && !_organizerReady)
                  ? null
                  : _send,
              child: Text(t(_busy ? 'Sending…' : 'Send request')),
            ),
          ],
        ),
      ),
    );
  }
}

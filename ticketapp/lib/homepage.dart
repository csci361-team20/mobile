import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api_client.dart';
import 'app_locale.dart';
import 'checkin_page.dart';
import 'mobile_labels.dart';
import 'mobile_operations_service.dart';
import 'mobile_support_page.dart';

import 'event_model.dart';
import 'event_service.dart';
import 'current_user.dart';
import 'ticket_type_model.dart';
import 'ticket_model.dart';
import 'auth_service.dart';
import 'auth.dart' show AppColors, AuthPage;

//--------------------------------
// Shared styles and small helpers
//--------------------------------
const TextStyle pageTitle = TextStyle(
  fontSize: 30,
  fontWeight: FontWeight.bold,
  color: AppColors.borderColor,
);

const RoundedRectangleBorder cardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(10)),
  side: BorderSide(color: Color(0xFFDDDDDD)),
);

String formatDate(DateTime d) {
  final value = d.toUtc().add(const Duration(hours: 5));
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute UTC+05';
}

String formatPrice(int price) => price == 0 ? 'Free' : '$price ₸';

IconData categoryIcon(String category) {
  switch (category) {
    case 'Music':
      return Icons.music_note;
    case 'Tech':
      return Icons.computer;
    case 'Sport':
      return Icons.sports_soccer;
    case 'Art':
      return Icons.palette;
    case 'Food':
      return Icons.restaurant;
    default:
      return Icons.event;
  }
}

//--------------------------------
// Models + fake data
//--------------------------------

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PrimaryButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

// White card with a border. Used for every block in the lists
class InfoCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const InfoCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.accentColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: cardShape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}

// Small colored label: Paid, Draft, Open...
class StatusChip extends StatelessWidget {
  final String text;

  const StatusChip(this.text, {super.key});

  Color _color() {
    switch (text) {
      case 'Paid':
      case 'Published':
      case 'Resolved':
        return Colors.green;
      case 'Verified':
        return Colors.green;
      case 'Pending':
      case 'Open':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

// Icon + text in one row (date, city, place)
class IconText extends StatelessWidget {
  final IconData icon;
  final String text;

  const IconText(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

//--------------------------------
// Main page with bottom navigation
//--------------------------------
typedef RefreshUser = Future<CurrentUser?> Function();

class Homepage extends StatefulWidget {
  final String accessToken;
  final CurrentUser currentUser;

  const Homepage({
    super.key,
    required this.accessToken,
    required this.currentUser,
  });

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int selectedIndex = 0;
  late CurrentUser _user;
  bool _leavingSession = false;
  final _ticketsKey = GlobalKey<_TicketsTabState>();

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
    ApiClient.instance.authenticated.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (ApiClient.instance.authenticated.value || _leavingSession) return;
    _leavingSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthPage()),
          (_) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    ApiClient.instance.authenticated.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<CurrentUser?> _refreshUser() async {
    try {
      final fresh = await fetchCurrentUser(widget.accessToken);
      if (!mounted) return null;
      setState(() => _user = fresh);
      return fresh;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh profile: $e')),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      EventsTab(accessToken: widget.accessToken),
      TicketsTab(key: _ticketsKey, accessToken: widget.accessToken),
      OrganizersTab(user: _user, onRefresh: _refreshUser),
      const CheckinPage(),
      ProfileTab(user: _user, onRefresh: _refreshUser),
    ];

    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          if (index == 1) _ticketsKey.currentState?.reload();
          setState(() => selectedIndex = index);
        },
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: AppColors.borderColor,
        backgroundColor: AppColors.accentColor,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.event),
            label: ml(context, 'Events'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.confirmation_number_outlined),
            label: ml(context, 'Tickets'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.business_center_outlined),
            label: ml(context, 'Organizers'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.qr_code_scanner),
            label: ml(context, 'Check-in'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: ml(context, 'Profile'),
          ),
        ],
      ),
    );
  }
}

//--------------------------------
// Tab 1: Events (search, category filter, sorting)
//--------------------------------

class EventsTab extends StatefulWidget {
  final String accessToken;

  const EventsTab({super.key, required this.accessToken});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final EventService _eventService = EventService();

  List<ApiEvent> _events = [];
  bool _isLoading = true;
  String? _error;

  final List<String> sortOptions = [
    'Date: soonest',
    'Price: low to high',
    'Price: high to low',
    'Name: A-Z',
  ];

  String search = '';
  String category = 'All';
  String sortBy = 'Date: soonest';
  bool freeOnly = false;

  List<String> get categories {
    final eventCategories =
        _events
            .map((event) => _categoryLabel(event.category))
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return ['All', ...eventCategories];
  }

  String _categoryLabel(String value) {
    if (value.isEmpty) return '';
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final events = await _eventService.fetchEvents();

      if (!mounted) return;

      setState(() {
        _events = events;
        _isLoading = false;

        if (category != 'All' && !categories.contains(category)) {
          category = 'All';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<ApiEvent> get visibleEvents {
    final result = _events.where((event) {
      final query = search.toLowerCase();

      final matchesSearch =
          event.title.toLowerCase().contains(query) ||
          event.city.toLowerCase().contains(query) ||
          event.venueName.toLowerCase().contains(query);

      final matchesCategory =
          category == 'All' || _categoryLabel(event.category) == category;

      final matchesFree = !freeOnly || event.priceFromKzt == 0;

      return matchesSearch && matchesCategory && matchesFree;
    }).toList();

    if (sortBy == 'Date: soonest') {
      result.sort((a, b) => a.startAt.compareTo(b.startAt));
    } else if (sortBy == 'Price: low to high') {
      result.sort((a, b) => a.priceFromKzt.compareTo(b.priceFromKzt));
    } else if (sortBy == 'Price: high to low') {
      result.sort((a, b) => b.priceFromKzt.compareTo(a.priceFromKzt));
    } else {
      result.sort((a, b) => a.title.compareTo(b.title));
    }

    return result;
  }

  void showEventDetails(ApiEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.accentColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EventDetailsSheet(
        event: event,
        eventService: _eventService,
        accessToken: widget.accessToken,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final events = visibleEvents;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Events', style: pageTitle),
            const SizedBox(height: 12),

            TextField(
              decoration: const InputDecoration(
                hintText: 'Search events',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => search = value),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: categories.map((c) {
                  final selected = category == c;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: AppColors.primaryColor,
                      backgroundColor: AppColors.accentColor,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textMain,
                      ),
                      onSelected: (_) {
                        setState(() => category = c);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            Row(
              children: [
                const Icon(Icons.sort, color: Colors.black54),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: sortBy,
                  underline: const SizedBox(),
                  items: sortOptions
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => sortBy = value);
                    }
                  },
                ),
                const Spacer(),
                const Text('Free only'),
                Switch(
                  value: freeOnly,
                  activeTrackColor: AppColors.primaryColor,
                  onChanged: (value) {
                    setState(() => freeOnly = value);
                  },
                ),
              ],
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Could not load events.'),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadEvents,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  : events.isEmpty
                  ? const Center(child: Text('No events found'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];

                        return EventCard(
                          event: event,
                          onTap: () => showEventDetails(event),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventDetailsSheet extends StatefulWidget {
  final ApiEvent event;
  final EventService eventService;
  final String accessToken;

  const EventDetailsSheet({
    super.key,
    required this.event,
    required this.eventService,
    required this.accessToken,
  });

  @override
  State<EventDetailsSheet> createState() => _EventDetailsSheetState();
}

class _EventDetailsSheetState extends State<EventDetailsSheet> {
  late Future<List<TicketType>> _ticketTypesFuture;

  TicketType? _selectedTicket;
  int _quantity = 1;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _ticketTypesFuture = widget.eventService.fetchTicketTypes(widget.event.id);
  }

  Future<void> _checkout(TicketType ticket) async {
    if (_isSubmitting) return;

    final isFree = ticket.priceKzt == 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isFree ? 'Confirm registration' : 'Confirm purchase'),
        content: Text(
          isFree
              ? 'Register for ${widget.event.title}?'
              : 'Purchase $_quantity × ${ticket.name} '
                    'for ${formatPrice(ticket.priceKzt * _quantity)}?\n\n'
                    'Payment is simulated in this version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final order = await widget.eventService.createOrder(
        eventId: widget.event.id,
        ticketTypeId: ticket.id,
        quantity: _quantity,
        accessToken: widget.accessToken,
      );

      Map<String, dynamic> result = order;

      if (!isFree) {
        result = await widget.eventService.payOrder(
          orderId: order['id'].toString(),
          accessToken: widget.accessToken,
        );
      }

      if (!mounted) return;

      final status = result['status']?.toString() ?? '';

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'confirmed'
                ? 'Order confirmed! Your tickets are ready.'
                : 'Order status: $status',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Order failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              if (event.category.isNotEmpty)
                IconText(categoryIcon(event.category), event.category),

              IconText(Icons.location_on_outlined, event.city),

              if (event.venueName.isNotEmpty)
                IconText(Icons.place_outlined, event.venueName),

              IconText(Icons.calendar_today, formatDate(event.startAt)),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MobileSupportPage(eventId: event.id),
                  ),
                ),
                icon: const Icon(Icons.support_agent),
                label: Text(ml(context, 'Get support')),
              ),

              if (event.description != null &&
                  event.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(event.description!),
              ],

              const SizedBox(height: 20),
              const Text(
                'Available tickets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              FutureBuilder<List<TicketType>>(
                future: _ticketTypesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Could not load ticket types.'),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _ticketTypesFuture = widget.eventService
                                  .fetchTicketTypes(event.id);
                            });
                          },
                          child: const Text('Try again'),
                        ),
                      ],
                    );
                  }

                  final tickets = snapshot.data ?? [];

                  if (tickets.isEmpty) {
                    return const Text('No ticket types available.');
                  }

                  final availableTickets = tickets
                      .where((ticket) => ticket.isAvailable)
                      .toList();

                  if (availableTickets.isEmpty) {
                    return const Text('All tickets are currently unavailable.');
                  }

                  final selected = availableTickets.firstWhere(
                    (ticket) => ticket.id == _selectedTicket?.id,
                    orElse: () => availableTickets.first,
                  );

                  if (_selectedTicket?.id != selected.id) {
                    _selectedTicket = selected;
                    _quantity = 1;
                  }

                  final maxQuantity = [
                    selected.available,
                    selected.maxPerOrder,
                    10,
                  ].reduce((a, b) => a < b ? a : b);

                  if (_quantity > maxQuantity) {
                    _quantity = maxQuantity;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RadioGroup<String>(
                        groupValue: selected.id,
                        onChanged: (value) {
                          if (value == null) return;

                          final ticket = availableTickets.firstWhere(
                            (ticket) => ticket.id == value,
                          );

                          setState(() {
                            _selectedTicket = ticket;
                            _quantity = 1;
                          });
                        },
                        child: Column(
                          children: availableTickets.map((ticket) {
                            return RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              value: ticket.id,
                              title: Text(ticket.name),
                              subtitle: Text(
                                '${formatPrice(ticket.priceKzt)}'
                                ' • ${ticket.available} available',
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Quantity',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: _quantity < maxQuantity
                                ? () => setState(() => _quantity++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Text(
                        'Total: ${formatPrice(selected.priceKzt * _quantity)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),

                      const SizedBox(height: 20),
                      PrimaryButton(
                        text: _isSubmitting
                            ? 'Processing...'
                            : selected.priceKzt == 0
                            ? 'Register'
                            : 'Buy ticket',
                        onPressed: _isSubmitting
                            ? () {}
                            : () => _checkout(selected),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final ApiEvent event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child:
                event.coverImageUrl != null && event.coverImageUrl!.isNotEmpty
                ? Image.network(
                    event.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        categoryIcon(event.category),
                        color: AppColors.primaryColor,
                        size: 32,
                      );
                    },
                  )
                : Icon(
                    categoryIcon(event.category),
                    color: AppColors.primaryColor,
                    size: 32,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconText(Icons.calendar_today, formatDate(event.startAt)),
                IconText(Icons.location_on_outlined, event.city),
                const SizedBox(height: 6),
                Text(
                  formatPrice(event.priceFromKzt),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
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

//--------------------------------
// Tab 2: Tickets (Upcoming / Past)
//--------------------------------

class TicketsTab extends StatefulWidget {
  final String accessToken;

  const TicketsTab({super.key, required this.accessToken});

  @override
  State<TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<TicketsTab> {
  final EventService _eventService = EventService();

  late Future<List<ApiTicket>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  void _loadTickets() {
    _ticketsFuture = _eventService.fetchMyTickets(widget.accessToken);
  }

  void reload() {
    setState(_loadTickets);
  }

  Future<void> _refreshTickets() async {
    setState(_loadTickets);
    await _ticketsFuture;
  }

  void showTicketDetails(ApiTicket ticket) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.accentColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ticket.eventTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Text(ticket.ticketTypeName),
              const SizedBox(height: 8),

              IconText(Icons.calendar_today, formatDate(ticket.eventStartAt)),

              if (ticket.city.isNotEmpty)
                IconText(Icons.location_on_outlined, ticket.city),

              if (ticket.venueName.isNotEmpty)
                IconText(Icons.place_outlined, ticket.venueName),

              const SizedBox(height: 16),
              StatusChip(ticket.status),
              const SizedBox(height: 20),

              if (ticket.qrPayload?.isNotEmpty == true &&
                  (ticket.status == 'valid' || ticket.status == 'checked_in'))
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: ticket.qrPayload!,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                )
              else
                Text(ml(sheetContext, 'QR payload is not available')),
              const SizedBox(height: 8),

              Text(
                ml(sheetContext, 'Ticket reference'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              SelectableText(ticket.id, textAlign: TextAlign.center),

              const SizedBox(height: 20),
              Text(
                'Attendee: ${ticket.attendeeName}',
                textAlign: TextAlign.center,
              ),
              Text(
                ticket.attendeeEmail,
                style: const TextStyle(color: Colors.black54),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  sheetContext,
                  MaterialPageRoute(
                    builder: (_) => MobileSupportPage(
                      ticketId: ticket.id,
                      orderId: ticket.orderId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.support_agent),
                label: Text(ml(sheetContext, 'Get support')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ticketCard(ApiTicket ticket) {
    return InfoCard(
      onTap: () => showTicketDetails(ticket),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.eventTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              StatusChip(ticket.status),
            ],
          ),

          IconText(Icons.confirmation_number_outlined, ticket.ticketTypeName),

          IconText(Icons.calendar_today, formatDate(ticket.eventStartAt)),

          if (ticket.city.isNotEmpty)
            IconText(Icons.location_on_outlined, ticket.city),

          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.qr_code_2, color: AppColors.primaryColor),
              SizedBox(width: 6),
              Text(
                'Tap to view ticket',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketList(List<ApiTicket> tickets, bool upcoming) {
    final now = DateTime.now();

    final filtered = tickets.where((ticket) {
      final isUpcoming = ticket.eventStartAt.isAfter(now);
      return upcoming ? isUpcoming : !isUpcoming;
    }).toList();

    filtered.sort(
      (a, b) => upcoming
          ? a.eventStartAt.compareTo(b.eventStartAt)
          : b.eventStartAt.compareTo(a.eventStartAt),
    );

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              upcoming ? 'No upcoming tickets yet' : 'No past tickets yet',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _ticketCard(filtered[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('My tickets', style: pageTitle),
              ),
            ),

            const TabBar(
              labelColor: AppColors.primaryColor,
              unselectedLabelColor: AppColors.borderColor,
              indicatorColor: AppColors.primaryColor,
              tabs: [
                Tab(text: 'Upcoming'),
                Tab(text: 'Past'),
              ],
            ),

            Expanded(
              child: FutureBuilder<List<ApiTicket>>(
                future: _ticketsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Could not load your tickets.'),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(_loadTickets);
                            },
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    );
                  }

                  final tickets = snapshot.data ?? [];

                  return TabBarView(
                    children: [
                      RefreshIndicator(
                        onRefresh: _refreshTickets,
                        child: _buildTicketList(tickets, true),
                      ),
                      RefreshIndicator(
                        onRefresh: _refreshTickets,
                        child: _buildTicketList(tickets, false),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//--------------------------------
// Tab 3: For organizers
//--------------------------------
class OrganizersTab extends StatefulWidget {
  final CurrentUser user;
  final RefreshUser onRefresh;
  const OrganizersTab({super.key, required this.user, required this.onRefresh});
  @override
  State<OrganizersTab> createState() => _OrganizersTabState();
}

class _OrganizersTabState extends State<OrganizersTab> {
  final _service = MobileOperationsService();
  late Future<List<Map<String, dynamic>>> _events;

  @override
  void initState() {
    super.initState();
    _events = _service.managedEvents();
  }

  Future<void> _refresh() async {
    final next = _service.managedEvents();
    setState(() => _events = next);
    await next;
  }

  Future<void> _openEditor() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MobileEventEditor()),
    );
    if (mounted) {
      setState(() => _events = _service.managedEvents());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(ml(context, 'For organizers'), style: pageTitle),
                ),
                IconButton(
                  tooltip: ml(context, 'Refresh'),
                  onPressed: () =>
                      setState(() => _events = _service.managedEvents()),
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: ml(context, 'Support'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MobileSupportPage(organizer: true),
                    ),
                  ),
                  icon: const Icon(Icons.support_agent),
                ),
              ],
            ),
          ),
          if (!widget.user.isEmailVerified)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(ml(context, 'Verify your email to create events.')),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VerifyEmailPage(
                          user: widget.user,
                          onRefresh: widget.onRefresh,
                        ),
                      ),
                    ),
                    child: Text(ml(context, 'Verify email')),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.user.isEmailVerified ? _openEditor : null,
                icon: const Icon(Icons.add),
                label: Text(ml(context, 'Create event')),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _events,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${snapshot.error}'),
                          TextButton(
                            onPressed: () => setState(
                              () => _events = _service.managedEvents(),
                            ),
                            child: Text(ml(context, 'Try again')),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final events = snapshot.data ?? [];
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (events.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            ml(context, 'No managed events yet'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final event in events)
                        InfoCard(
                          onTap: () async {
                            await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MobileManagedEventPage(
                                  event: event,
                                  isAdmin: widget.user.isPlatformAdmin,
                                ),
                              ),
                            );
                            if (mounted) {
                              setState(
                                () => _events = _service.managedEvents(),
                              );
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${event['title'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ml(
                                  context,
                                  '${event['lifecycle'] ?? event['status'] ?? ''}',
                                ),
                              ),
                              Text(
                                '${ml(context, 'Your role')}: ${ml(context, '${event['my_role'] ?? ''}')}',
                              ),
                              Text(
                                '${event['venue_name'] ?? ''} · ${event['city'] ?? ''}',
                              ),
                              Text('${event['start_at'] ?? ''}'),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MobileManagedEventPage extends StatefulWidget {
  final Map<String, dynamic> event;
  final bool isAdmin;
  const MobileManagedEventPage({
    super.key,
    required this.event,
    required this.isAdmin,
  });
  @override
  State<MobileManagedEventPage> createState() => _MobileManagedEventPageState();
}

class _MobileManagedEventPageState extends State<MobileManagedEventPage> {
  final _service = MobileOperationsService();
  late Map<String, dynamic> _event;
  late Future<List<Map<String, dynamic>>> _tickets;
  bool _busy = false;
  String? _error;
  bool _changed = false;
  String get _id => '${_event['id']}';
  bool get _editable =>
      _event['status'] != 'cancelled' &&
      _event['lifecycle'] != 'completed' &&
      _event['status'] != 'completed';
  bool get _canManage =>
      widget.isAdmin || ['owner', 'manager'].contains(_event['my_role']);

  @override
  void initState() {
    super.initState();
    _event = Map<String, dynamic>.from(widget.event);
    _tickets = _service.ticketTypes(_id);
  }

  Future<void> _act(String action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (action == 'cancel') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(ml(context, 'Cancel event')),
            content: Text(
              ml(
                context,
                'Cancel this event? Paid orders are refunded by the backend and tickets become invalid.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(ml(context, 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(ml(context, 'Cancel event')),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      final response = await _service.eventAction(_id, action);
      if (!mounted) return;
      _changed = true;
      if (action == 'duplicate') {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _event = {...response, 'my_role': _event['my_role']};
        _tickets = _service.ticketTypes(_id);
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => MobileEventEditor(existing: _event)),
    );
    if (result != null && mounted) {
      setState(() {
        _event = {...result, 'my_role': _event['my_role']};
        _changed = true;
      });
    }
  }

  Future<void> _addTicket() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MobileTicketTypeEditor(eventId: _id)),
    );
    if (created == true && mounted) {
      setState(() {
        _tickets = _service.ticketTypes(_id);
        _changed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_event['title'] ?? ''}'),
          leading: IconButton(
            onPressed: _busy ? null : () => Navigator.pop(context, _changed),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              ml(context, '${_event['lifecycle'] ?? _event['status'] ?? ''}'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('${_event['start_at'] ?? ''} – ${_event['end_at'] ?? ''}'),
            Text('${_event['venue_name'] ?? ''} · ${_event['city'] ?? ''}'),
            Text('${ml(context, 'Capacity')}: ${_event['capacity'] ?? ''}'),
            if (_event['description'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('${_event['description']}'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_canManage)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (_editable)
                    OutlinedButton(
                      onPressed: _busy ? null : _edit,
                      child: Text(ml(context, 'Edit event')),
                    ),
                  if (_editable && _event['status'] == 'draft')
                    FilledButton(
                      onPressed: _busy ? null : () => _act('publish'),
                      child: Text(ml(context, 'Publish')),
                    ),
                  if (_editable && _event['status'] == 'published')
                    OutlinedButton(
                      onPressed: _busy ? null : () => _act('unpublish'),
                      child: Text(ml(context, 'Unpublish')),
                    ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _act('duplicate'),
                    child: Text(ml(context, 'Duplicate')),
                  ),
                  if (_editable &&
                      (widget.isAdmin || _event['my_role'] == 'owner'))
                    OutlinedButton(
                      onPressed: _busy ? null : () => _act('cancel'),
                      child: Text(ml(context, 'Cancel event')),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    ml(context, 'Ticket types'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_editable &&
                    _canManage &&
                    _event['seating_type'] != 'assigned')
                  IconButton(
                    onPressed: _busy ? null : _addTicket,
                    tooltip: ml(context, 'Add ticket type'),
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _tickets,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      Text('${snapshot.error}'),
                      TextButton(
                        onPressed: () => setState(
                          () => _tickets = _service.ticketTypes(_id),
                        ),
                        child: Text(ml(context, 'Try again')),
                      ),
                    ],
                  );
                }
                final tickets = snapshot.data ?? [];
                return Column(
                  children: [
                    if (tickets.isEmpty)
                      Text(
                        ml(
                          context,
                          'No ticket types yet. Add one before publishing.',
                        ),
                      ),
                    for (final ticket in tickets)
                      Card(
                        child: ListTile(
                          title: Text('${ticket['name'] ?? ''}'),
                          subtitle: Text(
                            '${ml(context, 'Quantity')}: ${ticket['quantity']}',
                          ),
                          trailing: Text('${ticket['price_kzt']} ₸'),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MobileSupportPage(organizer: true, eventId: _id),
                ),
              ),
              icon: const Icon(Icons.support_agent),
              label: Text(ml(context, 'Get support')),
            ),
          ],
        ),
      ),
    );
  }
}

class MobileEventEditor extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const MobileEventEditor({super.key, this.existing});
  @override
  State<MobileEventEditor> createState() => _MobileEventEditorState();
}

class _MobileEventEditorState extends State<MobileEventEditor> {
  final _service = MobileOperationsService();
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  String _visibility = 'public';
  bool _busy = false;
  String? _error;
  final _labels = const {
    'title': 'Event title',
    'description': 'Description',
    'venue_name': 'Venue',
    'city': 'City',
    'capacity': 'Capacity',
  };

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final tomorrow = DateTime.now().toUtc().add(
      const Duration(days: 1, hours: 5),
    );
    final start =
        DateTime.tryParse('${existing?['start_at'] ?? ''}')
            ?.toUtc()
            .add(const Duration(hours: 5)) ??
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19);
    final end =
        DateTime.tryParse('${existing?['end_at'] ?? ''}')
            ?.toUtc()
            .add(const Duration(hours: 5)) ??
        start.add(const Duration(hours: 2));
    String day(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    String time(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    _fields = {
      for (final key in _labels.keys)
        key: TextEditingController(
          text: '${existing?[key] ?? (key == 'capacity' ? 100 : '')}',
        ),
      'start_date': TextEditingController(text: day(start)),
      'start_time': TextEditingController(text: time(start)),
      'end_date': TextEditingController(text: day(end)),
      'end_time': TextEditingController(text: time(end)),
    };
    _visibility = '${existing?['visibility'] ?? 'public'}';
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(String key) async {
    if (_busy) return;
    final isDate = key.endsWith('date');
    if (isDate) {
      final value = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(_fields[key]!.text) ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(DateTime.now().year + 5),
      );
      if (value != null && mounted) {
        setState(
          () => _fields[key]!.text =
              '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
        );
      }
    } else {
      final parts = _fields[key]!.text.split(':');
      final value = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: int.tryParse(parts.first) ?? 19,
          minute: int.tryParse(parts.last) ?? 0,
        ),
      );
      if (value != null && mounted) {
        setState(
          () => _fields[key]!.text =
              '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
        );
      }
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final start =
        '${_fields['start_date']!.text}T${_fields['start_time']!.text}:00+05:00';
    final end =
        '${_fields['end_date']!.text}T${_fields['end_time']!.text}:00+05:00';
    if (!DateTime.parse(end).isAfter(DateTime.parse(start))) {
      setState(
        () => _error = ml(context, 'The event must end after it starts.'),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = <String, dynamic>{
      for (final key in ['title', 'description', 'venue_name', 'city'])
        key: _fields[key]!.text.trim(),
      'start_at': start,
      'end_at': end,
      'capacity': int.parse(_fields['capacity']!.text),
      'visibility': _visibility,
      if (widget.existing == null) 'timezone': 'Asia/Almaty',
    };
    try {
      final event = widget.existing == null
          ? await _service.createEvent(body)
          : await _service.updateEvent('${widget.existing!['id']}', body);
      if (!mounted) return;
      setState(() => _busy = false);
      if (widget.existing == null) {
        Navigator.pop(context, true);
      } else {
        Navigator.pop(context, event);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          ml(context, widget.existing == null ? 'Create event' : 'Edit event'),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final entry in _labels.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  controller: _fields[entry.key],
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: ml(context, entry.value),
                  ),
                  maxLines: entry.key == 'description' ? 3 : 1,
                  maxLength: entry.key == 'title' ? 255 : null,
                  keyboardType: entry.key == 'capacity'
                      ? TextInputType.number
                      : TextInputType.text,
                  validator: (value) {
                    if (entry.key == 'title' &&
                        (value?.trim().length ?? 0) < 3) {
                      return ml(
                        context,
                        'Use at least 3 characters for the title.',
                      );
                    }
                    if (entry.key == 'capacity' &&
                        (int.tryParse(value ?? '') ?? 0) < 1) {
                      return ml(context, 'Enter a positive whole capacity.');
                    }
                    return null;
                  },
                ),
              ),
            Text(ml(context, 'Times are in Kazakhstan (UTC+05:00).')),
            for (final entry in const {
              'start_date': 'Start date',
              'start_time': 'Start time',
              'end_date': 'End date',
              'end_time': 'End time',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextFormField(
                  controller: _fields[entry.key],
                  readOnly: true,
                  enabled: !_busy,
                  onTap: () => _pick(entry.key),
                  decoration: InputDecoration(
                    labelText: ml(context, entry.value),
                    suffixIcon: Icon(
                      entry.key.endsWith('date')
                          ? Icons.calendar_today
                          : Icons.schedule,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: InputDecoration(labelText: ml(context, 'Visibility')),
              items: [
                for (final value in ['public', 'unlisted', 'private'])
                  DropdownMenuItem(
                    value: value,
                    child: Text(ml(context, value)),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _visibility = value!),
            ),
            if (widget.existing == null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  ml(
                    context,
                    'Create the event first, then add ticket types before publishing.',
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(ml(context, _busy ? 'Saving…' : 'Save')),
            ),
          ],
        ),
      ),
    ),
  );
}

class MobileTicketTypeEditor extends StatefulWidget {
  final String eventId;
  const MobileTicketTypeEditor({super.key, required this.eventId});
  @override
  State<MobileTicketTypeEditor> createState() => _MobileTicketTypeEditorState();
}

class _MobileTicketTypeEditorState extends State<MobileTicketTypeEditor> {
  final _service = MobileOperationsService();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController(text: '0');
  final _quantity = TextEditingController(text: '100');
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.createTicketType(widget.eventId, {
        'name': _name.text.trim(),
        'price_kzt': int.parse(_price.text),
        'quantity': int.parse(_quantity.text),
      });
      if (mounted) {
        setState(() => _busy = false);
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text(ml(context, 'Add ticket type'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              enabled: !_busy,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: ml(context, 'Ticket name'),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? ml(
                      context,
                      'Enter a ticket name, non-negative price and positive quantity.',
                    )
                  : null,
            ),
            TextFormField(
              controller: _price,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: ml(context, 'Price (KZT)'),
              ),
              validator: (value) => (int.tryParse(value ?? '') ?? -1) < 0
                  ? ml(
                      context,
                      'Enter a ticket name, non-negative price and positive quantity.',
                    )
                  : null,
            ),
            TextFormField(
              controller: _quantity,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: ml(context, 'Quantity')),
              validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                  ? ml(
                      context,
                      'Enter a ticket name, non-negative price and positive quantity.',
                    )
                  : null,
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(ml(context, _busy ? 'Saving…' : 'Save')),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProfileTab extends StatelessWidget {
  final CurrentUser user;
  final RefreshUser onRefresh;
  const ProfileTab({super.key, required this.user, required this.onRefresh});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ml(context, 'Log out')),
        content: Text(ml(context, 'Are you sure you want to log out?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ml(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ml(context, 'Log out')),
          ),
        ],
      ),
    );
    if (confirmed == true) await logoutSession();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(ml(context, 'Profile'), style: pageTitle),
        const SizedBox(height: 24),
        const Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primaryColor,
            child: Icon(Icons.person, size: 48, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.fullName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(user.email, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Center(
          child: StatusChip(
            ml(context, user.isEmailVerified ? 'Verified' : 'Not verified'),
          ),
        ),
        const SizedBox(height: 24),
        InfoCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MobileAccountEditor(user: user, onRefresh: onRefresh),
            ),
          ),
          child: ListTile(
            leading: const Icon(Icons.manage_accounts),
            title: Text(ml(context, 'Account details')),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
        if (!user.isEmailVerified)
          InfoCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    VerifyEmailPage(user: user, onRefresh: onRefresh),
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.mark_email_unread_outlined),
              title: Text(ml(context, 'Verify email')),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        InfoCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MobileSupportPage()),
          ),
          child: ListTile(
            leading: const Icon(Icons.support_agent),
            title: Text(ml(context, 'Support')),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
        InfoCard(
          onTap: () => _logout(context),
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(
              ml(context, 'Log out'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ],
    ),
  );
}

class MobileAccountEditor extends StatefulWidget {
  final CurrentUser user;
  final RefreshUser onRefresh;
  const MobileAccountEditor({
    super.key,
    required this.user,
    required this.onRefresh,
  });
  @override
  State<MobileAccountEditor> createState() => _MobileAccountEditorState();
}

class _MobileAccountEditorState extends State<MobileAccountEditor> {
  late final TextEditingController _name;
  late String _language;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.fullName);
    _language = widget.user.preferredLanguage;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.length < 2 ||
        name.length > 100 ||
        !RegExp(r"^[\p{L} '-]+$", unicode: true).hasMatch(name) ||
        name.replaceAll(RegExp(r"[ '-]"), '').isEmpty) {
      setState(
        () => _error = ml(
          context,
          'Use 2–100 characters: letters, spaces, hyphens or apostrophes.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient.instance.patch(
        '/users/me',
        body: {'full_name': name, 'preferred_language': _language},
      );
      await AppLocale.setLocale(_language);
      final fresh = await widget.onRefresh();
      if (!mounted) return;
      setState(() => _busy = false);
      if (fresh != null) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text(ml(context, 'Account details'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            enabled: !_busy,
            maxLength: 100,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(labelText: ml(context, 'Full name')),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: InputDecoration(labelText: ml(context, 'Language')),
            items: [
              for (final entry in const {
                'en': 'English',
                'ru': 'Russian',
                'kk': 'Kazakh',
              }.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(ml(context, entry.value)),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _language = value!),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(ml(context, _busy ? 'Saving…' : 'Save')),
          ),
        ],
      ),
    ),
  );
}

class VerifyEmailPage extends StatefulWidget {
  final CurrentUser user;
  final RefreshUser onRefresh;
  const VerifyEmailPage({
    super.key,
    required this.user,
    required this.onRefresh,
  });
  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _notice;
  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _run(String action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (action == 'request') {
        await ApiClient.instance.post('/auth/verify-email/request');
        if (mounted) {
          setState(
            () => _notice = ml(
              context,
              'Verification email requested. Check your inbox.',
            ),
          );
        }
      } else {
        if (action == 'confirm') {
          final text = _token.text.trim();
          final token = Uri.tryParse(text)?.queryParameters['token'] ?? text;
          if (token.length < 10) {
            throw ApiException(400, ml(context, 'Verification token'));
          }
          await ApiClient.instance.post(
            '/auth/verify-email/confirm',
            body: {'token': token},
          );
        }
        final fresh = await widget.onRefresh();
        if (!mounted) return;
        if (fresh?.isEmailVerified == true) {
          Navigator.pop(context);
          return;
        }
        setState(() => _notice = ml(context, 'Not verified'));
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(ml(context, 'Verify email'))),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(
          Icons.mark_email_unread_outlined,
          size: 72,
          color: AppColors.primaryColor,
        ),
        const SizedBox(height: 20),
        Text(
          widget.user.email,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          ml(
            context,
            'Open the emailed link, or paste its token here, then refresh your profile.',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _busy ? null : () => _run('request'),
          child: Text(ml(context, 'Request verification email')),
        ),
        TextField(
          controller: _token,
          enabled: !_busy,
          maxLength: 2048,
          decoration: InputDecoration(
            labelText: ml(context, 'Verification token'),
          ),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _run('confirm'),
          child: Text(ml(context, 'Confirm token')),
        ),
        OutlinedButton(
          onPressed: _busy ? null : () => _run('refresh'),
          child: Text(ml(context, 'Refresh')),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_notice != null) Text(_notice!),
      ],
    ),
  );
}

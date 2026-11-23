import 'package:flutter/material.dart';

import 'auth.dart' show AppColors, AuthPage, Validators;

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
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
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
// Models + fake data (later replaced by server data)
//--------------------------------
class EventItem {
  final String title;
  final String category;
  final String city;
  final DateTime date;
  final int price; // 0 = free

  EventItem({
    required this.title,
    required this.category,
    required this.city,
    required this.date,
    required this.price,
  });
}

class TicketItem {
  final String eventTitle;
  final String ticketType;
  final String place;
  final DateTime date;
  final int price;
  String status; // Paid, Pending, Refunded

  TicketItem({
    required this.eventTitle,
    required this.ticketType,
    required this.place,
    required this.date,
    required this.price,
    required this.status,
  });
}

class OrganizerEvent {
  final String title;
  final DateTime date;
  final int price;
  final int sold;
  final int capacity;
  String status; // Draft, Published, Cancelled

  OrganizerEvent({
    required this.title,
    required this.date,
    required this.price,
    required this.sold,
    required this.capacity,
    required this.status,
  });
}

class SupportCase {
  final String subject;
  final String message;
  final String status; // Open, Resolved

  SupportCase({
    required this.subject,
    required this.message,
    required this.status,
  });
}

final List<EventItem> allEvents = [
  EventItem(
    title: 'Astana Jazz Night',
    category: 'Music',
    city: 'Astana',
    date: DateTime(2026, 12, 5),
    price: 8000,
  ),
  EventItem(
    title: 'Modern Art Expo',
    category: 'Art',
    city: 'Astana',
    date: DateTime(2026, 12, 8),
    price: 2500,
  ),
  EventItem(
    title: 'Flutter Kazakhstan Meetup',
    category: 'Tech',
    city: 'Astana',
    date: DateTime(2026, 12, 12),
    price: 0,
  ),
  EventItem(
    title: 'Chess Open',
    category: 'Sport',
    city: 'Astana',
    date: DateTime(2026, 12, 15),
    price: 0,
  ),
  EventItem(
    title: 'Winter Marathon 10K',
    category: 'Sport',
    city: 'Almaty',
    date: DateTime(2026, 12, 20),
    price: 3000,
  ),
  EventItem(
    title: 'Indie Rock Open Air',
    category: 'Music',
    city: 'Almaty',
    date: DateTime(2026, 12, 27),
    price: 12000,
  ),
  EventItem(
    title: 'Street Food Festival',
    category: 'Food',
    city: 'Shymkent',
    date: DateTime(2027, 1, 15),
    price: 1500,
  ),
  EventItem(
    title: 'AI Conference 2027',
    category: 'Tech',
    city: 'Almaty',
    date: DateTime(2027, 2, 3),
    price: 25000,
  ),
];

final List<TicketItem> allTickets = [
  TicketItem(
    eventTitle: 'Astana Jazz Night',
    ticketType: 'VIP',
    place: 'Astana Opera',
    date: DateTime(2026, 12, 5),
    price: 8000,
    status: 'Paid',
  ),
  TicketItem(
    eventTitle: 'Flutter Kazakhstan Meetup',
    ticketType: 'Standard',
    place: 'Astana Hub',
    date: DateTime(2026, 12, 12),
    price: 0,
    status: 'Paid',
  ),
  TicketItem(
    eventTitle: 'AI Conference 2027',
    ticketType: 'Early bird',
    place: 'Almaty Arena',
    date: DateTime(2027, 2, 3),
    price: 25000,
    status: 'Pending',
  ),
  TicketItem(
    eventTitle: 'Street Art Night',
    ticketType: 'Standard',
    place: 'Expo Center',
    date: DateTime(2026, 10, 10),
    price: 2000,
    status: 'Paid',
  ),
  TicketItem(
    eventTitle: 'Rock Fest 2026',
    ticketType: 'Standard',
    place: 'Almaty',
    date: DateTime(2026, 9, 5),
    price: 10000,
    status: 'Refunded',
  ),
];

//--------------------------------
// Reusable widgets
//--------------------------------

// Orange rounded button, same style as the buttons in auth.dart
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
class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int selectedIndex = 0;

  final List<Widget> tabs = const [
    EventsTab(),
    TicketsTab(),
    OrganizersTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps every tab alive (search text, scroll position)
      body: IndexedStack(index: selectedIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => setState(() => selectedIndex = index),
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: AppColors.borderColor,
        backgroundColor: AppColors.accentColor,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_outlined),
            label: 'Tickets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_center_outlined),
            label: 'For organizers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
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
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final List<String> categories = [
    'All',
    'Music',
    'Tech',
    'Sport',
    'Art',
    'Food',
  ];
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

  // Applies search + filters + sorting to the full list
  List<EventItem> get visibleEvents {
    final result = allEvents.where((e) {
      final matchesSearch = e.title.toLowerCase().contains(
        search.toLowerCase(),
      );
      final matchesCategory = category == 'All' || e.category == category;
      final matchesFree = !freeOnly || e.price == 0;
      return matchesSearch && matchesCategory && matchesFree;
    }).toList();

    if (sortBy == 'Date: soonest') {
      result.sort((a, b) => a.date.compareTo(b.date));
    } else if (sortBy == 'Price: low to high') {
      result.sort((a, b) => a.price.compareTo(b.price));
    } else if (sortBy == 'Price: high to low') {
      result.sort((a, b) => b.price.compareTo(a.price));
    } else {
      result.sort((a, b) => a.title.compareTo(b.title));
    }
    return result;
  }

  void showEventDetails(EventItem event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.accentColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            IconText(categoryIcon(event.category), event.category),
            IconText(Icons.location_on_outlined, event.city),
            IconText(Icons.calendar_today, formatDate(event.date)),
            const SizedBox(height: 12),
            Text(
              formatPrice(event.price),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: event.price == 0 ? 'Register' : 'Buy ticket',
              onPressed: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Demo: ${event.title}')));
              },
            ),
          ],
        ),
      ),
    );
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

            // Search
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search events',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => search = value),
            ),
            const SizedBox(height: 12),

            // Category chips (scroll sideways)
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
                      onSelected: (_) => setState(() => category = c),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Sorting + free only
            Row(
              children: [
                const Icon(Icons.sort, color: Colors.black54),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: sortBy,
                  underline: const SizedBox(),
                  items: sortOptions
                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (value) => setState(() => sortBy = value!),
                ),
                const Spacer(),
                const Text('Free only'),
                Switch(
                  value: freeOnly,
                  activeTrackColor: AppColors.primaryColor,
                  onChanged: (value) => setState(() => freeOnly = value),
                ),
              ],
            ),

            // The scrollable list of event blocks
            Expanded(
              child: events.isEmpty
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

class EventCard extends StatelessWidget {
  final EventItem event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      onTap: onTap,
      child: Row(
        children: [
          // Placeholder for the event image
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
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
                IconText(Icons.calendar_today, formatDate(event.date)),
                IconText(Icons.location_on_outlined, event.city),
                const SizedBox(height: 6),
                Text(
                  formatPrice(event.price),
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
  const TicketsTab({super.key});

  @override
  State<TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<TicketsTab> {
  void showTicketDetails(TicketItem ticket) {
    final canRefund =
        ticket.status == 'Paid' && ticket.date.isAfter(DateTime.now());

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.accentColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ticket.eventTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('${ticket.ticketType} • ${formatDate(ticket.date)}'),
            const SizedBox(height: 16),
            // Placeholder for the real QR code
            const Icon(Icons.qr_code_2, size: 160),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Download PDF',
              onPressed: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo: PDF download')),
                );
              },
            ),
            if (canRefund) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() => ticket.status = 'Refunded');
                  Navigator.pop(sheetContext);
                },
                child: const Text(
                  'Request refund',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildList(List<TicketItem> tickets) {
    if (tickets.isEmpty) {
      return const Center(child: Text('No tickets here yet'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        final ticket = tickets[index];
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
              IconText(Icons.calendar_today, formatDate(ticket.date)),
              IconText(Icons.location_on_outlined, ticket.place),
              const SizedBox(height: 8),
              Text(
                '${ticket.ticketType} • ${formatPrice(ticket.price)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Upcoming: soonest first. Past: most recent first
    final upcoming = allTickets.where((t) => t.date.isAfter(now)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final past = allTickets.where((t) => !t.date.isAfter(now)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

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
              child: TabBarView(
                children: [buildList(upcoming), buildList(past)],
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
  const OrganizersTab({super.key});

  @override
  State<OrganizersTab> createState() => _OrganizersTabState();
}

class _OrganizersTabState extends State<OrganizersTab> {
  final _titleController = TextEditingController();

  final List<OrganizerEvent> myEvents = [
    OrganizerEvent(
      title: 'Astana Jazz Night',
      date: DateTime(2026, 12, 5),
      price: 8000,
      sold: 120,
      capacity: 200,
      status: 'Published',
    ),
    OrganizerEvent(
      title: 'Winter Hackathon',
      date: DateTime(2027, 1, 20),
      price: 0,
      sold: 0,
      capacity: 100,
      status: 'Draft',
    ),
    OrganizerEvent(
      title: 'Old Meetup',
      date: DateTime(2026, 11, 1),
      price: 1000,
      sold: 15,
      capacity: 50,
      status: 'Cancelled',
    ),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void handleAction(OrganizerEvent event, String action) {
    setState(() {
      if (action == 'publish') {
        event.status = 'Published';
      } else if (action == 'unpublish') {
        event.status = 'Draft';
      } else if (action == 'cancel') {
        event.status = 'Cancelled';
      } else if (action == 'duplicate') {
        myEvents.add(
          OrganizerEvent(
            title: '${event.title} (copy)',
            date: event.date,
            price: event.price,
            sold: 0,
            capacity: event.capacity,
            status: 'Draft',
          ),
        );
      }
    });
  }

  void showCreateDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New event'),
        content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Event title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final title = _titleController.text.trim();
              if (title.isEmpty) return;
              setState(() {
                myEvents.add(
                  OrganizerEvent(
                    title: title,
                    date: DateTime.now().add(const Duration(days: 30)),
                    price: 0,
                    sold: 0,
                    capacity: 100,
                    status: 'Draft',
                  ),
                );
              });
              _titleController.clear();
              Navigator.pop(dialogContext);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget statBox(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.accentColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDDDDDD)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEventCard(OrganizerEvent event) {
    final progress = event.capacity == 0 ? 0.0 : event.sold / event.capacity;

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              StatusChip(event.status),
              PopupMenuButton<String>(
                onSelected: (action) => handleAction(event, action),
                itemBuilder: (context) => [
                  if (event.status == 'Draft')
                    const PopupMenuItem(
                      value: 'publish',
                      child: Text('Publish'),
                    ),
                  if (event.status == 'Published')
                    const PopupMenuItem(
                      value: 'unpublish',
                      child: Text('Unpublish'),
                    ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicate'),
                  ),
                  if (event.status != 'Cancelled')
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel event'),
                    ),
                ],
              ),
            ],
          ),
          IconText(Icons.calendar_today, formatDate(event.date)),
          const SizedBox(height: 10),
          Text('Sold: ${event.sold} / ${event.capacity}'),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            color: AppColors.primaryColor,
            backgroundColor: const Color(0xFFDDDDDD),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSold = myEvents.fold<int>(0, (sum, e) => sum + e.sold);
    final revenue = myEvents.fold<int>(0, (sum, e) => sum + e.sold * e.price);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('For organizers', style: pageTitle),
          const SizedBox(height: 16),

          // Verification banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: Colors.orange),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Verify your identity to sell paid tickets'),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VerifyProfilePage(),
                    ),
                  ),
                  child: const Text('Verify'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats
          Row(
            children: [
              statBox('Events', '${myEvents.length}'),
              statBox('Tickets sold', '$totalSold'),
              statBox('Revenue', '$revenue ₸'),
            ],
          ),
          const SizedBox(height: 16),

          PrimaryButton(text: '+ Create event', onPressed: showCreateDialog),
          const SizedBox(height: 16),

          const Text(
            'My events',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...myEvents.map(buildEventCard),
        ],
      ),
    );
  }
}

//--------------------------------
// Tab 4: Profile
//--------------------------------
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  void confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Go back to the login screen and remove all previous screens
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
                (route) => false,
              );
            },
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = AppColors.textMain,
  }) {
    return InfoCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 16, color: color)),
          ),
          const Icon(Icons.chevron_right, color: Colors.black38),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Profile', style: pageTitle),
          const SizedBox(height: 24),

          // User info
          const Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primaryColor,
              child: Icon(Icons.person, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Aidar Nurlan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const Center(
            child: Text(
              'aidar@example.com',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: StatusChip('Not verified')),
          const SizedBox(height: 24),

          menuItem(
            icon: Icons.verified_user_outlined,
            title: 'Verify profile',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerifyProfilePage()),
            ),
          ),
          menuItem(
            icon: Icons.support_agent,
            title: 'Support',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportPage()),
            ),
          ),
          menuItem(
            icon: Icons.logout,
            title: 'Log out',
            color: Colors.red,
            onTap: () => confirmLogout(context),
          ),
        ],
      ),
    );
  }
}

//--------------------------------
// Verify profile screen
//--------------------------------
class VerifyProfilePage extends StatefulWidget {
  const VerifyProfilePage({super.key});

  @override
  State<VerifyProfilePage> createState() => _VerifyProfilePageState();
}

class _VerifyProfilePageState extends State<VerifyProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Server request will be here later
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Verification request sent')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify profile'),
        backgroundColor: AppColors.accentColor,
        foregroundColor: AppColors.borderColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Confirm your identity to become a verified organizer.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full legal name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => Validators.required(v, field: 'Name'),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _idController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ID number (IIN)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length != 12) {
                      return 'IIN must contain 12 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demo: photo upload')),
                    );
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload ID photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.borderColor,
                    minimumSize: const Size.fromHeight(55),
                  ),
                ),
                const SizedBox(height: 32),
                PrimaryButton(text: 'Submit', onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//--------------------------------
// Support screen (list of cases + new case)
//--------------------------------
class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  final List<SupportCase> cases = [
    SupportCase(
      subject: 'Refund for Rock Fest',
      message: 'I could not attend. Please refund.',
      status: 'Resolved',
    ),
    SupportCase(
      subject: 'Ticket PDF is empty',
      message: 'The PDF does not show a QR code.',
      status: 'Open',
    ),
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void showNewCaseDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New support case'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final subject = _subjectController.text.trim();
              if (subject.isEmpty) return;
              setState(() {
                // insert(0, ...) puts the newest case on top
                cases.insert(
                  0,
                  SupportCase(
                    subject: subject,
                    message: _messageController.text.trim(),
                    status: 'Open',
                  ),
                );
              });
              _subjectController.clear();
              _messageController.clear();
              Navigator.pop(dialogContext);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: AppColors.accentColor,
        foregroundColor: AppColors.borderColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showNewCaseDialog,
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New case'),
      ),
      body: cases.isEmpty
          ? const Center(child: Text('No support cases yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cases.length,
              itemBuilder: (context, index) {
                final item = cases[index];
                return InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.subject,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          StatusChip(item.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.message,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

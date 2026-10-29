# Mobile application specifications and architecture.

## Architecture of the project

### Project roles:

| Role | Description | Required pages |
|---|---|---|
| PLATFORM ADMIN | Administration with full access to the service | - |
| EVENT ADMIN | Check validity of the tickets | - |
| OGANIZER | Create, modify and manage events | - |
| ATTENDEE | Browse available events and buy tickets | - |


### Project authorization graph



### Project pages according to roles

*All pages:*
-Authorization:
1) Login
2) Register
3) Verify email???
4) Forgot password???
5) Reset password
-Attendee:
1) Event list
2) Event details
3) Checkout
4) My orders
5) Order details
6) Ticket details
-Organizer:
1) Event list with status: (upcoming, active, completed, cancelled)
2) Event editor: (create, dublicate, modify)
3) Event manage: Overview, Ticket types, Stapp, Analytics
4) Organizer Profile
-Event admin:
1) Assigned event list: list of available events
2) Scanner:
3) Attendee list:
Platform admin:
1) User list: search, ban
2) Event list: search, bam
3) Payments: records, refunds, promos
4) Settings and reports???
Shared profile/support:
1) Support page: list of cases with status????
2) Create support case????
3) Support chat????
4) Account: progile info, logout
5) Event list (Common)

Total 27

*Project architecture*
lib/
├── main.dart
├── app.dart                     # MaterialApp + router setup
├── core/
│   ├── api/
│   │   ├── api_client.dart      # single Dio instance + interceptors
│   │   └── api_exception.dart
│   ├── storage/
│   │   └── secure_storage.dart  # token persistence
│   └── theme/
├── models/                      # Dart classes mirroring backend entities
│   ├── user.dart
│   ├── event.dart
│   ├── ticket_type.dart
│   ├── order.dart
│   ├── ticket.dart
│   └── ...
├── services/                    # one per backend module — the only layer that calls the API
│   ├── auth_service.dart
│   ├── events_service.dart
│   ├── tickets_service.dart
│   ├── orders_service.dart
│   ├── promotions_service.dart
│   ├── support_service.dart
│   ├── checkin_service.dart
│   └── admin_service.dart
├── routing/
│   └── app_router.dart          # go_router config + auth/role redirects
└── features/
    ├── auth/                    # login, register, verify, forgot, reset
    ├── attendee/                # home, event_detail, seat_map, checkout, tickets, support
    ├── organizer/                # dashboard, wizard, manage tabs, analytics
    ├── checkin/                  # assigned events, scanner, results
    ├── admin/                    # dashboard, users, moderation, settings
    └── shared_widgets/           # event_card, ticket_card, status_chip, etc.
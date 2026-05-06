import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_l10n.dart';
import '../../models/interaction.dart';
import '../../models/reminder.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/organization_provider.dart';
import '../../providers/reminders_provider.dart';
import '../../services/storage_service.dart';

class ContactHistoryScreen extends ConsumerStatefulWidget {
  final String contactId;

  const ContactHistoryScreen({super.key, required this.contactId});

  @override
  ConsumerState<ContactHistoryScreen> createState() =>
      _ContactHistoryScreenState();
}

class _ContactHistoryScreenState extends ConsumerState<ContactHistoryScreen> {
  List<Interaction> _interactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ref
        .read(contactsProvider.notifier)
        .getInteractions(widget.contactId);
    if (mounted) {
      setState(() {
        _interactions = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final canViewHistory = ref.watch(orgCanViewHistoryProvider);
    final currentUserId = StorageService.currentUser?.id ?? '';

    final remindersState = ref.watch(remindersProvider);
    var doneForContact = remindersState.doneReminders
        .where((r) => r.contactIds.contains(widget.contactId))
        .toList();

    var interactions = _interactions;
    if (!canViewHistory) {
      // Only show history entries the current user authored themselves.
      interactions = interactions
          .where((i) => i.ownerId == currentUserId)
          .toList();
      doneForContact = doneForContact
          .where((r) => r.ownerId == currentUserId)
          .toList();
    }

    final entries = <_HistoryEntry>[
      ...interactions.map((i) => _HistoryEntry.fromInteraction(i, l10n)),
      ...doneForContact.map((r) => _HistoryEntry.fromReminder(r, l10n)),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 24,
              left: 24,
              right: 24,
            ),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  l10n.fullHistory,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_rounded,
                                size: 48, color: AppColors.hint(context)),
                            const SizedBox(height: 16),
                            Text(
                              l10n.noHistory,
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.hint(context),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: AppColors.borderColor(context),
                        ),
                        itemBuilder: (context, index) =>
                            _historyRow(context, entries[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(BuildContext context, _HistoryEntry entry) {
    Color dotColor;
    switch (entry.kind) {
      case _HistoryKind.reminderDone:
        dotColor = AppColors.accent;
        break;
      case _HistoryKind.edit:
        dotColor = AppColors.primary;
        break;
      case _HistoryKind.interaction:
        switch (entry.type) {
          case 'call':
            dotColor = AppColors.success;
            break;
          case 'email':
            dotColor = AppColors.warm;
            break;
          case 'meeting':
            dotColor = AppColors.accent;
            break;
          default:
            dotColor = AppColors.primary;
        }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.content,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy HH:mm').format(entry.date),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.hint(context),
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

enum _HistoryKind { interaction, reminderDone, edit }

class _HistoryEntry {
  final _HistoryKind kind;
  final String type;
  final String content;
  final String label;
  final DateTime date;

  const _HistoryEntry({
    required this.kind,
    required this.type,
    required this.content,
    required this.label,
    required this.date,
  });

  factory _HistoryEntry.fromInteraction(Interaction i, AppL10n l10n) {
    final isEdit = i.type == 'edit';
    return _HistoryEntry(
      kind: isEdit ? _HistoryKind.edit : _HistoryKind.interaction,
      type: i.type,
      content: i.content,
      label: isEdit ? l10n.modificationBadge : i.typeLabel.toUpperCase(),
      date: i.createdAt,
    );
  }

  factory _HistoryEntry.fromReminder(Reminder r, AppL10n l10n) {
    return _HistoryEntry(
      kind: _HistoryKind.reminderDone,
      type: 'reminder',
      content: r.note,
      label: l10n.completedReminderBadge,
      date: r.sortKey,
    );
  }
}

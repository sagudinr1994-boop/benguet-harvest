import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _db = Supabase.instance.client;

  String? _myId;
  String _myName = '';
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _init() async {
    final farmer = await AuthService.getLocalFarmer();
    if (farmer == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _myId = farmer['id'] as String;
    _myName = farmer['name'] as String? ?? '';
    await _load();
    _subscribeRealtime();
  }

  Future<void> _load() async {
    if (_myId == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      final data = await _db
          .from('conversations')
          .select('''
            id, last_message, last_at, last_message_sender_id,
            farmer_a:farmer_a_id(id, name, barangay),
            farmer_b:farmer_b_id(id, name, barangay)
          ''')
          .or('farmer_a_id.eq.$_myId,farmer_b_id.eq.$_myId')
          .order('last_at', ascending: false);

      final List<Map<String, dynamic>> enriched = [];
      for (final conv in List<Map<String, dynamic>>.from(data)) {
        final convId = conv['id'] as String;
        final unreadRows = await _db
            .from('messages')
            .select('id')
            .eq('conversation_id', convId)
            .neq('sender_id', _myId!)
            .isFilter('read_at', null);
        enriched.add({...conv, 'unread': (unreadRows as List).length});
      }

      if (mounted) setState(() {
        _conversations = enriched;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = _db
        .channel('inbox_${_myId ?? 'anon'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Map<String, dynamic> _otherFarmer(Map<String, dynamic> conv) {
    final a = conv['farmer_a'] as Map<String, dynamic>;
    final b = conv['farmer_b'] as Map<String, dynamic>;
    return (a['id'] as String) == _myId ? b : a;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        title: const Text(
          '💬 Messages',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _myId == null
          ? const Center(
              child: Text(
                'Log in to use messages.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
                )
              : RefreshIndicator(
                  color: const Color(0xFF1C3A28),
                  onRefresh: _load,
                  child: _conversations.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No messages yet.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Tap a farm pin on the map\nto start a conversation.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          itemCount: _conversations.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 72),
                          itemBuilder: (_, i) =>
                              _buildTile(_conversations[i]),
                        ),
                ),
    );
  }

  Widget _buildTile(Map<String, dynamic> conv) {
    final other = _otherFarmer(conv);
    final name = other['name'] as String? ?? 'Unknown';
    final barangay = other['barangay'] as String? ?? '';
    final lastMsg = conv['last_message'] as String? ?? '';
    final lastAt = DateTime.tryParse(conv['last_at'] as String? ?? '');
    final unread = conv['unread'] as int? ?? 0;
    final lastSenderId = conv['last_message_sender_id'] as String? ?? '';
    final iMine = lastSenderId == _myId;

    final now = DateTime.now();
    final timeStr = lastAt == null
        ? ''
        : now.difference(lastAt).inDays == 0
            ? DateFormat('h:mm a').format(lastAt.toLocal())
            : now.difference(lastAt).inDays < 7
                ? DateFormat('EEE').format(lastAt.toLocal())
                : DateFormat('MMM d').format(lastAt.toLocal());

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor:
            unread > 0 ? const Color(0xFF1C3A28) : Colors.grey.shade200,
        child: Text(
          name[0].toUpperCase(),
          style: TextStyle(
            color: unread > 0 ? const Color(0xFFE8B84B) : Colors.black54,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
          color: const Color(0xFF1C3A28),
          fontSize: 15,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (barangay.isNotEmpty)
            Text(
              barangay,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          if (lastMsg.isNotEmpty)
            Text(
              '${iMine ? 'You: ' : ''}$lastMsg',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unread > 0 ? Colors.black87 : Colors.grey,
                fontWeight:
                    unread > 0 ? FontWeight.w500 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeStr,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1C3A28),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unread',
                style: const TextStyle(
                  color: Color(0xFFE8B84B),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conv['id'] as String,
              myId: _myId!,
              myName: _myName,
              otherName: name,
              otherFarmerId: other['id'] as String,
            ),
          ),
        );
        _load();
      },
    );
  }
}

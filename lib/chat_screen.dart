import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String myId;
  final String myName;
  final String otherName;
  final String otherFarmerId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.myId,
    required this.myName,
    required this.otherName,
    required this.otherFarmerId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db = Supabase.instance.client;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _db
          .from('messages')
          .select()
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
        _markRead();
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead() async {
    await _db
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', widget.conversationId)
        .eq('sender_id', widget.otherFarmerId)
        .isFilter('read_at', null);
  }

  void _subscribeRealtime() {
    _channel = _db
        .channel('chat_${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) {
            final newMsg = payload.newRecord;
            if (mounted) {
              setState(() => _messages.add(Map<String, dynamic>.from(newMsg)));
              if ((newMsg['sender_id'] as String?) != widget.myId) _markRead();
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      await _db.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': widget.myId,
        'body': body,
      });
      await _db.from('conversations').update({
        'last_message': body,
        'last_at': DateTime.now().toIso8601String(),
        'last_message_sender_id': widget.myId,
      }).eq('id', widget.conversationId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        iconTheme: const IconThemeData(color: Color(0xFFE8B84B)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherName,
              style: const TextStyle(
                color: Color(0xFFE8B84B),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Text(
              'Farmer',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Say hello! 👋',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildBubble(_messages[i]),
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final isMe = (msg['sender_id'] as String?) == widget.myId;
    final body = msg['body'] as String? ?? '';
    final createdAt = DateTime.tryParse(msg['created_at'] as String? ?? '');
    final timeStr =
        createdAt != null ? DateFormat('h:mm a').format(createdAt.toLocal()) : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1C3A28) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              body,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeStr,
              style: TextStyle(
                color: isMe ? Colors.white54 : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF2EDE6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF1C3A28),
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Color(0xFFE8B84B),
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, color: Color(0xFFE8B84B), size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

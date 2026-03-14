import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'chat_screen.dart';

class MessagingService {
  static final _db = Supabase.instance.client;

  /// Returns conversation ID, creating one if it doesn't exist.
  static Future<String> findOrCreateConversation(
    String myId,
    String otherId,
  ) async {
    final existing = await _db
        .from('conversations')
        .select('id')
        .or(
          'and(farmer_a_id.eq.$myId,farmer_b_id.eq.$otherId),'
          'and(farmer_a_id.eq.$otherId,farmer_b_id.eq.$myId)',
        )
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final result = await _db
        .from('conversations')
        .insert({'farmer_a_id': myId, 'farmer_b_id': otherId})
        .select('id')
        .single();
    return result['id'] as String;
  }

  /// Navigates to ChatScreen with the given farmer.
  static Future<void> openChat(
    BuildContext context, {
    required String otherFarmerId,
    required String otherName,
  }) async {
    final myFarmer = await AuthService.getLocalFarmer();
    if (myFarmer == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log in to send messages.')),
        );
      }
      return;
    }

    final myId = myFarmer['id'] as String;
    final myName = myFarmer['name'] as String? ?? '';

    if (myId == otherFarmerId) return;

    final convId = await findOrCreateConversation(myId, otherFarmerId);
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convId,
            myId: myId,
            myName: myName,
            otherName: otherName,
            otherFarmerId: otherFarmerId,
          ),
        ),
      );
    }
  }
}

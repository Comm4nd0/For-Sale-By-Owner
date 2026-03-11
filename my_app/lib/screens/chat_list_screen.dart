import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/chat_room.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatRoom> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final api = context.read<ApiService>();
      final rooms = await api.getChatRooms();
      if (mounted) setState(() { _rooms = rooms; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? const Center(child: Text('No conversations yet'))
              : RefreshIndicator(
                  onRefresh: _loadRooms,
                  child: ListView.builder(
                    itemCount: _rooms.length,
                    itemBuilder: (context, index) {
                      final room = _rooms[index];
                      final userId = context.read<AuthService>().userId;
                      final otherName = room.buyerId == userId
                          ? room.sellerName
                          : room.buyerName;
                      return ListTile(
                        leading: CircleAvatar(child: Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?')),
                        title: Text(otherName),
                        subtitle: Text(
                          room.lastMessage ?? room.propertyTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: room.unreadCount > 0
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: Text('${room.unreadCount}',
                                    style: const TextStyle(fontSize: 12, color: Colors.white)),
                              )
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(room: room),
                          ),
                        ).then((_) => _loadRooms()),
                      );
                    },
                  ),
                ),
    );
  }
}

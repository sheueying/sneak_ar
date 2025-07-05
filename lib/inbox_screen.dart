import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  final String role; // 'buyer' or 'seller'
  const InboxScreen({super.key, this.role = 'buyer'});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<Map<String, dynamic>?> _getOtherUserInfo(Map<String, dynamic> chatData) async {
    if (_userId == null) return null;
    final users = List<String>.from(chatData['users']);
    final otherId = users.firstWhere((id) => id != _userId);
    // Try to get from users collection first
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherId).get();
    if (userDoc.exists) {
      return {
        'id': otherId,
        'name': userDoc.data()?['username'] ?? 'User',
        'avatar': userDoc.data()?['profileImageUrl'] ?? '',
        'isSeller': false,
      };
    }
    // Try sellers collection
    final sellerDoc = await FirebaseFirestore.instance.collection('sellers').doc(otherId).get();
    if (sellerDoc.exists) {
      return {
        'id': otherId,
        'name': sellerDoc.data()?['storeName'] ?? 'Shop',
        'avatar': sellerDoc.data()?['profileImageUrl'] ?? '',
        'isSeller': true,
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }
    Query baseQuery = FirebaseFirestore.instance.collection('chats');
    if (widget.role == 'buyer') {
      baseQuery = baseQuery.where('customerId', isEqualTo: _userId);
    } else {
      baseQuery = baseQuery.where('sellerId', isEqualTo: _userId);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('My Inbox', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF4F7FB),
      body: StreamBuilder<QuerySnapshot>(
        stream: baseQuery.orderBy('lastTimestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data!.docs;
          if (chats.isEmpty) {
            return Center(child: Text('No conversations yet', style: GoogleFonts.dmSans()));
          }
          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final chatData = chat.data() as Map<String, dynamic>;
              return FutureBuilder<Map<String, dynamic>?>(
                future: _getOtherUserInfo(chatData),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const ListTile(title: Text('Loading...'));
                  }
                  final other = snapshot.data!;
                  final lastRead = chatData['lastRead'] != null ? chatData['lastRead'][_userId] : null;
                  final lastTimestamp = chatData['lastTimestamp'];
                  bool hasUnread = false;
                  if (lastTimestamp != null) {
                    if (lastRead == null) {
                      hasUnread = true;
                    } else if (lastRead is Timestamp && lastTimestamp is Timestamp) {
                      hasUnread = lastTimestamp.toDate().isAfter(lastRead.toDate());
                    }
                  }
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (other['avatar'] != null && other['avatar'].isNotEmpty)
                          ? NetworkImage(other['avatar'])
                          : const AssetImage('assets/default_profile.png') as ImageProvider,
                    ),
                    title: Text(other['name'], style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                    subtitle: Text(chatData['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (chatData['lastTimestamp'] != null)
                          Text(
                            _formatTimestamp(chatData['lastTimestamp']),
                            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey),
                          ),
                        if (hasUnread)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            sellerId: other['id'],
                            sellerName: other['name'],
                            sellerProfileImageUrl: other['avatar'],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        // Today: show time
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else {
        // Not today: show date
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    }
    return '';
  }
} 
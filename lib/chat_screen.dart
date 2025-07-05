import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatScreen extends StatefulWidget {
  final String sellerId;
  final String sellerName;
  final String? sellerProfileImageUrl;

  const ChatScreen({super.key, required this.sellerId, required this.sellerName, this.sellerProfileImageUrl});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _chatId;
  String? _customerId;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _customerId = user.uid;
    // Find or create chat document
    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('users', arrayContains: user.uid)
        .get();
    // Try to find a chat between this customer and seller
    String? foundChatId;
    for (var doc in chatQuery.docs) {
      final users = List<String>.from(doc['users']);
      if (users.contains(widget.sellerId) && users.contains(user.uid)) {
        foundChatId = doc.id;
        break;
      }
    }
    if (foundChatId != null) {
      setState(() { _chatId = foundChatId; });
      // Mark as read
      await FirebaseFirestore.instance.collection('chats').doc(foundChatId).update({
        'lastRead.${user.uid}': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new chat
      final docRef = await FirebaseFirestore.instance.collection('chats').add({
        'users': [user.uid, widget.sellerId],
        'customerId': user.uid,
        'sellerId': widget.sellerId,
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastRead': {user.uid: FieldValue.serverTimestamp()},
      });
      setState(() { _chatId = docRef.id; });
    }
  }

  void _sendMessage() async {
    if (_chatId == null || _controller.text.trim().isEmpty || _customerId == null) return;
    final text = _controller.text.trim();
    _controller.clear();
    final messageRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc();
    await messageRef.set({
      'senderId': _customerId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
    // Update last message in chat
    await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastRead.$_customerId': FieldValue.serverTimestamp(), // Mark as read after sending
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: (widget.sellerProfileImageUrl != null && widget.sellerProfileImageUrl!.isNotEmpty)
                  ? NetworkImage(widget.sellerProfileImageUrl!)
                  : const AssetImage('assets/default_profile.png') as ImageProvider,
            ),
            const SizedBox(width: 10),
            Text(widget.sellerName, style: GoogleFonts.dmSans(color: Colors.black, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: false,
      ),
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          Expanded(
            child: _chatId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(_chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      return ListView.builder(
                        reverse: true,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final msg = docs[index];
                          final isMe = msg['senderId'] == _customerId;
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blue[100] : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue[50]!, width: 1),
                              ),
                              child: Text(msg['text'], style: GoogleFonts.dmSans(fontSize: 15)),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.blue[100]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


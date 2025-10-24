import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/guild_model.dart';
import '../models/avatars.dart';
import 'profile_screen.dart';
import 'dart:async';

// Main Screen Widget
class GuildsScreen extends StatefulWidget {
  final String uid;
  const GuildsScreen({super.key, required this.uid});

  @override
  State<GuildsScreen> createState() => _GuildsScreenState();
}

class _GuildsScreenState extends State<GuildsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Guilds"),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.shield), text: "My Guild"),
            Tab(icon: Icon(Icons.search), text: "Find Guild"),
            Tab(icon: Icon(Icons.add_circle), text: "Create"),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF0F3460), const Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
            final user = User.fromFirestore(userSnapshot.data);

            return TabBarView(
              controller: _tabController,
              children: [
                _MyGuildView(user: user, tabController: _tabController),
                _FindGuildView(user: user),
                _CreateGuildView(user: user),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --- VIEW FOR THE USER'S CURRENT GUILD ---
class _MyGuildView extends StatelessWidget {
  final User user;
  final TabController tabController;
  const _MyGuildView({required this.user, required this.tabController});

  Future<void> _leaveGuild(BuildContext context, Guild guild) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(guild.leaderId == user.uid ? "Disband Guild?" : "Leave Guild?"),
        content: Text(guild.leaderId == user.uid
            ? "Are you sure? As the leader, disbanding the guild is permanent and will remove all members."
            : "Are you sure you want to leave ${guild.name}?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(guild.leaderId == user.uid ? "Disband" : "Leave")),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    final firestore = FirebaseFirestore.instance;
    final guildRef = firestore.collection('guilds').doc(user.guildId!);
    final userRef = firestore.collection('users').doc(user.uid);

    if (guild.leaderId == user.uid) {
      WriteBatch batch = firestore.batch();
      for (var memberId in guild.members) {
        batch.update(firestore.collection('users').doc(memberId), {'guildId': null});
      }
      batch.delete(guildRef);
      await batch.commit();
    } else {
      await guildRef.update({'members': FieldValue.arrayRemove([user.uid])});
      await userRef.update({'guildId': null});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user.guildId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield, color: Colors.grey, size: 80),
            const SizedBox(height: 20),
            const Text("You are not in a guild.", style: TextStyle(color: Colors.grey, fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => tabController.animateTo(1),
              icon: const Icon(Icons.search),
              label: const Text("Find a Guild"),
            ),
            const SizedBox(height: 8),
            const Text("or", style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () => tabController.animateTo(2),
              child: const Text("Create a new one"),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('guilds').doc(user.guildId).snapshots(),
      builder: (context, guildSnapshot) {
        if (!guildSnapshot.hasData || !guildSnapshot.data!.exists) {
          return const Center(child: Text("Guild not found.", style: TextStyle(color: Colors.red)));
        }
        final guild = Guild.fromFirestore(guildSnapshot.data!);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGuildHeader(context, guild, user), // Pass user for chat
            const Divider(height: 30, color: Colors.white24),
            Text("Members (${guild.members.length})", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            _buildMemberList(guild.members, guild.leaderId),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _leaveGuild(context, guild),
                icon: const Icon(Icons.exit_to_app),
                label: Text(guild.leaderId == user.uid ? "Disband Guild" : "Leave Guild"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuildHeader(BuildContext context, Guild guild, User user) {
    return Card(
      color: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                if (guild.emblemUrl != null)
                  Image.network(
                    guild.emblemUrl!,
                    height: 60,
                    width: 60,
                    // --- FIX: Added errorBuilder to prevent crashes ---
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 60, color: Colors.grey),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("[${guild.tag}] ${guild.name}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(guild.description, style: TextStyle(fontSize: 14, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GuildChatView(guild: guild, user: user),
                ));
              },
              icon: const Icon(Icons.chat),
              label: const Text("Guild Chat"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberList(List<String> memberIds, String leaderId) {
    return FutureBuilder<List<User>>(
      future: _getMemberDetails(memberIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final members = snapshot.data!;
        members.sort((a, b) => a.uid == leaderId ? -1 : 1);
        return Column(
          children: members.map((member) {
            final bool isLeader = member.uid == leaderId;
            return Card(
              color: const Color(0xFF16213E).withOpacity(0.7),
              child: ListTile(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => ProfileScreen(uid: member.uid))),
                leading: CircleAvatar(backgroundImage: NetworkImage(member.avatarUrl ?? avatarUrls.first)),
                title: Text(member.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("Level ${member.level}", style: const TextStyle(color: Colors.grey)),
                trailing: isLeader ? const Icon(Icons.star, color: Colors.amber, size: 20) : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<List<User>> _getMemberDetails(List<String> memberIds) async {
    final users = <User>[];
    for (var id in memberIds) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (doc.exists) users.add(User.fromFirestore(doc));
    }
    return users;
  }
}

// --- VIEW FOR FINDING A GUILD ---
class _FindGuildView extends StatefulWidget {
  final User user;
  const _FindGuildView({required this.user});
  @override
  State<_FindGuildView> createState() => _FindGuildViewState();
}
class _FindGuildViewState extends State<_FindGuildView> {
  Stream<QuerySnapshot>? _searchStream;

  void _search(String query) {
    if (query.isNotEmpty) {
      setState(() {
        _searchStream = FirebaseFirestore.instance.collection('guilds').where('tag', isEqualTo: query.toUpperCase()).snapshots();
      });
    } else {
      setState(() => _searchStream = null);
    }
  }

  Future<void> _joinGuild(String guildId) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('guilds').doc(guildId).update({'members': FieldValue.arrayUnion([widget.user.uid])});
    await firestore.collection('users').doc(widget.user.uid).update({'guildId': guildId});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: _search,
            decoration: InputDecoration(
              hintText: "Search by Guild Tag (e.g., CRIM)",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: _searchStream,
          builder: (context, snapshot) {
            if(_searchStream == null) return const Center(child: Text("Enter a tag to find a guild.", style: TextStyle(color: Colors.grey)));
            if(!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final guilds = snapshot.data!.docs;
            if(guilds.isEmpty) return const Center(child: Text("No guilds found.", style: TextStyle(color: Colors.grey)));

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: guilds.length,
              itemBuilder: (context, index) {
                final guild = Guild.fromFirestore(guilds[index]);
                return Card(
                  color: const Color(0xFF16213E),
                  child: ListTile(
                    leading: guild.emblemUrl != null ? Image.network(guild.emblemUrl!, height: 40, width: 40, errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 40)) : const Icon(Icons.shield),
                    title: Text("[${guild.tag}] ${guild.name}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(guild.description, style: TextStyle(color: Colors.grey.shade400)),
                    trailing: widget.user.guildId == null
                        ? ElevatedButton(onPressed: () => _joinGuild(guild.id), child: const Text("Join"))
                        : const Chip(label: Text("In Guild")),
                  ),
                );
              },
            );
          },
        ))
      ],
    );
  }
}

// --- VIEW FOR CREATING A GUILD ---
class _CreateGuildView extends StatefulWidget {
  final User user;
  const _CreateGuildView({required this.user});

  @override
  State<_CreateGuildView> createState() => _CreateGuildViewState();
}
class _CreateGuildViewState extends State<_CreateGuildView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  static const int _creationCost = 10000;

  Future<void> _createGuild() async {
    if(!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.user.uid);
    final guildsRef = firestore.collection('guilds');

    final newName = _nameController.text.trim();
    final newTag = _tagController.text.trim().toUpperCase();

    final existingTag = await guildsRef.where('tag', isEqualTo: newTag).limit(1).get();
    if(existingTag.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("That guild tag is already taken."), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
      return;
    }

    try {
      final newGuildRef = await guildsRef.add({
        'name': newName,
        'tag': newTag,
        'description': _descriptionController.text.trim(),
        'leaderId': widget.user.uid,
        'members': [widget.user.uid],
        'createdAt': Timestamp.now(),
        // --- FIX: Changed 'svg' to 'png' ---
        'emblemUrl': 'https://api.dicebear.com/8.x/icons/png?seed=$newTag',
      });
      await userRef.update({
        'guildId': newGuildRef.id,
        'gold': FieldValue.increment(-_creationCost),
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guild created successfully!"), backgroundColor: Colors.green));
      }

    } catch (e) {
      debugPrint("Error creating guild: $e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.guildId != null) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("You are already in a guild. You must leave it before creating a new one.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5)),
      ));
    }
    if (widget.user.gold < _creationCost) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text("You need $_creationCost Gold to create a guild. You currently have ${widget.user.gold}.", textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent, fontSize: 16, height: 1.5)),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Create a New Guild", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text("Cost: $_creationCost Gold", style: const TextStyle(color: Colors.amber, fontSize: 16)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Guild Name", border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().length < 3 ? "Name must be at least 3 characters." : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagController,
              decoration: const InputDecoration(labelText: "Guild Tag (3-4 characters)", border: OutlineInputBorder()),
              maxLength: 4,
              validator: (v) => v == null || v.trim().length < 3 ? "Tag must be 3-4 characters." : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
              maxLines: 3,
              validator: (v) => v == null || v.trim().isEmpty ? "Please enter a description." : null,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(onPressed: _createGuild, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text("Create Guild"))
          ],
        ),
      ),
    );
  }
}
// --- (GuildChatView and _ChatMessage widgets remain the same) ---
class GuildChatView extends StatefulWidget {
  final Guild guild;
  final User user;
  const GuildChatView({super.key, required this.guild, required this.user});

  @override
  State<GuildChatView> createState() => _GuildChatViewState();
}
class _GuildChatViewState extends State<GuildChatView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    await FirebaseFirestore.instance
        .collection('guilds')
        .doc(widget.guild.id)
        .collection('chat')
        .add({
      'senderId': widget.user.uid,
      'senderName': widget.user.name,
      'senderAvatarUrl': widget.user.avatarUrl,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Scroll to bottom after sending
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.guild.name} Chat"),
        backgroundColor: const Color(0xFF0F3460),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF0F3460), const Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('guilds')
                    .doc(widget.guild.id)
                    .collection('chat')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final messages = snapshot.data!.docs;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index].data() as Map<String, dynamic>;
                      final isMe = msg['senderId'] == widget.user.uid;

                      return _ChatMessage(
                        message: msg['text'] ?? '',
                        senderName: msg['senderName'] ?? 'Unknown',
                        avatarUrl: msg['senderAvatarUrl'] ?? avatarUrls.first,
                        isMe: isMe,
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.black.withOpacity(0.3),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Send a message...",
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.purpleAccent),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
class _ChatMessage extends StatelessWidget {
  final String message;
  final String senderName;
  final String avatarUrl;
  final bool isMe;

  const _ChatMessage({
    required this.message,
    required this.senderName,
    required this.avatarUrl,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isMe ? Colors.purpleAccent : const Color(0xFF16213E);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                if(!isMe) Text(senderName, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(message, style: TextStyle(color: isMe ? Colors.black : Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isMe) CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
        ],
      ),
    );
  }
}


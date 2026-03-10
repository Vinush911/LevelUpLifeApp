import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Added for time formatting
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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Guild Hall", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey.shade400,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
          tabs: const [
            Tab(icon: Icon(Icons.shield), text: "MY GUILD"),
            Tab(icon: Icon(Icons.search), text: "FIND"),
            Tab(icon: Icon(Icons.add_circle), text: "FOUND"),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F3460), Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
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
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent)),
        title: Text(
            guild.leaderId == user.uid ? "Disband Guild?" : "Leave Guild?",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        content: Text(
            guild.leaderId == user.uid
                ? "Are you sure? As the leader, disbanding the guild is permanent and will remove all members."
                : "Are you sure you want to leave ${guild.name}?",
            style: const TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: Text(guild.leaderId == user.uid ? "Disband" : "Leave", style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    final firestore = FirebaseFirestore.instance;
    final guildRef = firestore.collection('guilds').doc(user.guildId!);
    final userRef = firestore.collection('users').doc(user.uid);

    final bool isDisbanding = guild.leaderId == user.uid;

    if (isDisbanding) {
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

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isDisbanding ? "Guild disbanded." : "You have left the guild.", style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orangeAccent
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user.guildId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(Icons.shield_outlined, color: Colors.grey.withOpacity(0.5), size: 80),
            ),
            const SizedBox(height: 24),
            const Text("You are a lone wolf.", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Join a guild to adventure together.", style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => tabController.animateTo(1),
              icon: const Icon(Icons.search),
              label: const Text("Find a Guild", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => tabController.animateTo(2),
              child: const Text("Or found a new one", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('guilds').doc(user.guildId).snapshots(),
      builder: (context, guildSnapshot) {
        if (!guildSnapshot.hasData || !guildSnapshot.data!.exists) {
          return const Center(child: Text("Guild not found.", style: TextStyle(color: Colors.redAccent)));
        }
        final guild = Guild.fromFirestore(guildSnapshot.data!);

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildGuildHeader(context, guild, user),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.people, color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 8),
                Text("MEMBERS (${guild.members.length})", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.5)),
              ],
            ),
            const SizedBox(height: 12),
            _buildMemberList(guild.members, guild.leaderId),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _leaveGuild(context, guild),
                icon: const Icon(Icons.exit_to_app),
                label: Text(guild.leaderId == user.uid ? "Disband Guild" : "Leave Guild", style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildGuildHeader(BuildContext context, Guild guild, User user) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, spreadRadius: 1)],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.5))
                ),
                child: guild.emblemUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    guild.emblemUrl!,
                    height: 60,
                    width: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 60, color: Colors.amber),
                  ),
                )
                    : const Icon(Icons.shield, size: 60, color: Colors.amber),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber)),
                          child: Text(guild.tag, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(guild.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(guild.description, style: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontStyle: FontStyle.italic, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GuildChatView(guild: guild, user: user),
              ));
            },
            icon: const Icon(Icons.forum),
            label: const Text("Enter Guild Chat", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(45),
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList(List<String> memberIds, String leaderId) {
    return FutureBuilder<List<User>>(
      future: _getMemberDetails(memberIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Colors.cyanAccent)));
        final members = snapshot.data!;
        members.sort((a, b) => a.uid == leaderId ? -1 : 1);
        return Column(
          children: members.map((member) {
            final bool isLeader = member.uid == leaderId;
            return Card(
              color: const Color(0xFF16213E).withOpacity(isLeader ? 0.9 : 0.6),
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isLeader ? Colors.amber.withOpacity(0.5) : Colors.white10),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => ProfileScreen(uid: member.uid))),
                leading: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isLeader ? Colors.amber : Colors.cyanAccent, width: 1.5)),
                  child: CircleAvatar(backgroundImage: NetworkImage(member.avatarUrl ?? avatarUrls.first), backgroundColor: Colors.black45),
                ),
                title: Text(member.name, style: TextStyle(color: isLeader ? Colors.amber : Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("Level ${member.level} ${member.title}", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                trailing: isLeader
                    ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.star, color: Colors.amber, size: 16),
                )
                    : const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
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
  String? _joiningGuildId;

  void _search(String query) {
    if (query.isNotEmpty) {
      setState(() {
        _searchStream = FirebaseFirestore.instance.collection('guilds').where('tag', isEqualTo: query.toUpperCase()).snapshots();
      });
    } else {
      setState(() => _searchStream = null);
    }
  }

  Future<void> _joinGuild(String guildId, String guildName) async {
    setState(() => _joiningGuildId = guildId);
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('guilds').doc(guildId).update({'members': FieldValue.arrayUnion([widget.user.uid])});
      await firestore.collection('users').doc(widget.user.uid).update({'guildId': guildId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Welcome to $guildName!", style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error joining guild: $e"), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _joiningGuildId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search by Guild Tag (e.g., CRIM)",
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purpleAccent)),
            ),
          ),
        ),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: _searchStream,
          builder: (context, snapshot) {
            if(_searchStream == null) {
              return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.travel_explore, size: 64, color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text("Enter a tag to find a guild.", style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                    ],
                  )
              );
            }
            if(!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
            final guilds = snapshot.data!.docs;
            if(guilds.isEmpty) return const Center(child: Text("No guilds found with that tag.", style: TextStyle(color: Colors.grey)));

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: guilds.length,
              itemBuilder: (context, index) {
                final guild = Guild.fromFirestore(guilds[index]);
                return Card(
                  color: const Color(0xFF16213E).withOpacity(0.8),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                      child: guild.emblemUrl != null
                          ? Image.network(guild.emblemUrl!, height: 40, width: 40, errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 40, color: Colors.amber))
                          : const Icon(Icons.shield, color: Colors.amber, size: 40),
                    ),
                    title: Row(
                      children: [
                        Text("[${guild.tag}]", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(guild.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(guild.description, style: TextStyle(color: Colors.grey.shade400, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    trailing: widget.user.guildId == null
                        ? (_joiningGuildId == guild.id
                        ? const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2)))
                        : ElevatedButton(
                        onPressed: () => _joinGuild(guild.id, guild.name),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text("Join", style: TextStyle(fontWeight: FontWeight.bold))
                    )
                    )
                        : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                      child: const Text("IN GUILD", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
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

  String _previewTag = "TAG";
  bool _isLoading = false;
  static const int _creationCost = 10000;

  @override
  void initState() {
    super.initState();
    _tagController.addListener(() {
      setState(() {
        _previewTag = _tagController.text.trim().toUpperCase();
        if (_previewTag.isEmpty) _previewTag = "TAG";
      });
    });
  }

  Future<void> _createGuild() async {
    if(!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.user.uid);
    final guildsRef = firestore.collection('guilds');

    final newName = _nameController.text.trim();
    final newTag = _tagController.text.trim().toUpperCase();

    try {
      final existingTag = await guildsRef.where('tag', isEqualTo: newTag).limit(1).get();
      if(existingTag.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("That guild tag is already taken.", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orangeAccent));
        }
        setState(() => _isLoading = false);
        return;
      }

      final newGuildRef = await guildsRef.add({
        'name': newName,
        'tag': newTag,
        'description': _descriptionController.text.trim(),
        'leaderId': widget.user.uid,
        'members': [widget.user.uid],
        'createdAt': Timestamp.now(),
        'emblemUrl': 'https://api.dicebear.com/8.x/icons/png?seed=$newTag',
      });
      await userRef.update({
        'guildId': newGuildRef.id,
        'gold': FieldValue.increment(-_creationCost),
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guild created successfully! 🛡️", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
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
      return Center(child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text("You are already in a guild.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("You must leave your current guild before founding a new one.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          ],
        ),
      ));
    }

    final bool canAfford = widget.user.gold >= _creationCost;

    if (!canAfford) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.money_off, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text("Insufficient Funds", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  "You need $_creationCost Gold to found a guild.\nYou currently have ${widget.user.gold} Gold.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14, height: 1.5)
              ),
            ],
          ),
        ),
      ));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- DYNAMIC EMBLEM PREVIEW ---
            Center(
              child: Column(
                children: [
                  Text("Guild Emblem Preview", style: TextStyle(color: Colors.grey.shade400, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
                      boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        'https://api.dicebear.com/8.x/icons/png?seed=$_previewTag',
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 80, color: Colors.amber),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF16213E).withOpacity(0.8), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))),
              child: Column(
                children: [
                  const Text("Found a New Guild", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Charter Cost: ", style: TextStyle(color: Colors.grey)),
                      Text("$_creationCost Gold", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField(controller: _nameController, label: "Guild Name", icon: Icons.shield, validator: (v) => v == null || v.trim().length < 3 ? "Name must be at least 3 characters." : null),
            const SizedBox(height: 16),
            _buildTextField(controller: _tagController, label: "Guild Tag (3-4 characters)", icon: Icons.label, maxLength: 4, isTag: true, validator: (v) => v == null || v.trim().length < 3 ? "Tag must be 3-4 characters." : null),
            const SizedBox(height: 16),
            _buildTextField(controller: _descriptionController, label: "Description / Motto", icon: Icons.description, maxLines: 3, validator: (v) => v == null || v.trim().isEmpty ? "Please enter a description." : null),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                : ElevatedButton.icon(
              onPressed: _createGuild,
              icon: const Icon(Icons.add_moderator),
              label: const Text("Establish Guild", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, int? maxLength, int maxLines = 1, bool isTag = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      textCapitalization: isTag ? TextCapitalization.characters : TextCapitalization.sentences,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: Colors.purpleAccent),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.purpleAccent)),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: validator,
    );
  }
}

// --- GUILD CHAT VIEW ---
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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.guild.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Text("Guild Chat", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 2,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F3460), Color(0xFF1A1A2E)],
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
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                  final messages = snapshot.data!.docs;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });

                  if (messages.isEmpty) {
                    return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined, size: 60, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            const Text("The hall is quiet. Say hello!", style: TextStyle(color: Colors.grey)),
                          ],
                        )
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index].data() as Map<String, dynamic>;
                      final isMe = msg['senderId'] == widget.user.uid;

                      final timestamp = msg['timestamp'] as Timestamp?;
                      final timeStr = timestamp != null ? DateFormat.jm().format(timestamp.toDate()) : '';

                      return _ChatMessage(
                        message: msg['text'] ?? '',
                        senderName: msg['senderName'] ?? 'Unknown',
                        avatarUrl: msg['senderAvatarUrl'] ?? avatarUrls.first,
                        timeString: timeStr,
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
      padding: const EdgeInsets.all(12.0).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        border: Border(top: BorderSide(color: Colors.purpleAccent.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: "Send a message to the guild...",
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              color: Colors.purpleAccent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black, size: 20),
              onPressed: _sendMessage,
            ),
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
  final String timeString;
  final bool isMe;

  const _ChatMessage({
    required this.message,
    required this.senderName,
    required this.avatarUrl,
    required this.timeString,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isMe ? Colors.purpleAccent.withOpacity(0.9) : const Color(0xFF16213E).withOpacity(0.9);
    final textColor = Colors.white;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(radius: 16, backgroundImage: NetworkImage(avatarUrl), backgroundColor: Colors.black26),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                if(!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                    child: Text(senderName, style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: borderRadius,
                    border: isMe ? null : Border.all(color: Colors.white10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(child: Text(message, style: TextStyle(color: textColor, fontSize: 15, height: 1.3))),
                      if (timeString.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(timeString, style: TextStyle(color: isMe ? Colors.white70 : Colors.white54, fontSize: 10)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: CircleAvatar(radius: 16, backgroundImage: NetworkImage(avatarUrl), backgroundColor: Colors.black26),
            ),
        ],
      ),
    );
  }
}
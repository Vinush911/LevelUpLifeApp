import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/avatars.dart';
import 'profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  final String uid;
  const FriendsScreen({super.key, required this.uid});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
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
        title: const Text("Companions", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
            Tab(icon: Icon(Icons.people), text: "ALLIES"),
            Tab(icon: Icon(Icons.person_add), text: "REQUESTS"),
            Tab(icon: Icon(Icons.search), text: "SEARCH"),
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
        child: TabBarView(
          controller: _tabController,
          children: [
            _FriendsListView(uid: widget.uid),
            _RequestsListView(uid: widget.uid),
            _AddFriendView(uid: widget.uid),
          ],
        ),
      ),
    );
  }
}

// --- Tab for displaying current friends ---
class _FriendsListView extends StatelessWidget {
  final String uid;
  const _FriendsListView({required this.uid});

  Future<void> _removeFriend(BuildContext context, String friendUid, String friendName) async {
    final firestore = FirebaseFirestore.instance;
    final currentUserRef = firestore.collection('users').doc(uid);
    final friendUserRef = firestore.collection('users').doc(friendUid);

    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent)),
        title: Text("Remove $friendName?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to sever your ties with this adventurer? This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text("Remove", style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await currentUserRef.update({'friends': FieldValue.arrayRemove([friendUid])});
      await friendUserRef.update({'friends': FieldValue.arrayRemove([uid])});
      if(context.mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$friendName has been removed from your party.", style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orangeAccent));
      }
    }
  }

  void _viewProfile(BuildContext context, String friendUid) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ProfileScreen(uid: friendUid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
        final user = User.fromFirestore(snapshot.data);

        if (user.friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(Icons.people_outline, color: Colors.grey.withOpacity(0.5), size: 80),
                ),
                const SizedBox(height: 24),
                const Text("Your party is empty.", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Use the search tab to find companions.", style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
              ],
            ),
          );
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: _getFriendDetails(user.friends),
          builder: (context, friendsSnapshot) {
            if (!friendsSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
            final friends = friendsSnapshot.data!;
            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friendDoc = friends[index];
                final friend = User.fromFirestore(friendDoc);
                final imageUrl = friend.avatarUrl ?? avatarUrls.first;

                return Card(
                  color: const Color(0xFF16213E).withOpacity(0.8),
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onTap: () => _viewProfile(context, friendDoc.id),
                    leading: Container(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5)
                      ),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundImage: NetworkImage(imageUrl),
                        backgroundColor: Colors.black45,
                        onBackgroundImageError: (_, __) {},
                      ),
                    ),
                    title: Text(friend.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text("Level ${friend.level} ${friend.title}", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ),
                    trailing: Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.person_remove, color: Colors.redAccent, size: 20),
                        tooltip: "Remove Companion",
                        onPressed: () => _removeFriend(context, friendDoc.id, friend.name),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<DocumentSnapshot>> _getFriendDetails(List<String> friendIds) async {
    final List<DocumentSnapshot> friends = [];
    for (String id in friendIds) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (doc.exists) {
        friends.add(doc);
      }
    }
    return friends;
  }
}

// --- Tab for displaying friend requests ---
class _RequestsListView extends StatelessWidget {
  final String uid;
  const _RequestsListView({required this.uid});

  Future<void> _handleRequest(String otherUid, bool accept) async {
    final firestore = FirebaseFirestore.instance;
    final currentUserRef = firestore.collection('users').doc(uid);
    final otherUserRef = firestore.collection('users').doc(otherUid);

    if (accept) {
      await currentUserRef.update({
        'friends': FieldValue.arrayUnion([otherUid]),
        'friendRequestsReceived': FieldValue.arrayRemove([otherUid]),
      });
      await otherUserRef.update({
        'friends': FieldValue.arrayUnion([uid]),
        'friendRequestsSent': FieldValue.arrayRemove([uid]),
      });
    } else {
      await currentUserRef.update({'friendRequestsReceived': FieldValue.arrayRemove([otherUid])});
      await otherUserRef.update({'friendRequestsSent': FieldValue.arrayRemove([uid])});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
        final user = User.fromFirestore(snapshot.data);

        if (user.friendRequestsReceived.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 64, color: Colors.grey.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text("No pending scrolls or requests.", style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
              ],
            ),
          );
        }

        return FutureBuilder<List<User>>(
          future: _getFriendDetails(user.friendRequestsReceived),
          builder: (context, requestsSnapshot) {
            if (!requestsSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
            final requests = requestsSnapshot.data!;
            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final requestUser = requests[index];
                final requestUid = user.friendRequestsReceived[index];
                final imageUrl = requestUser.avatarUrl ?? avatarUrls.first;

                return Card(
                  color: const Color(0xFF16213E).withOpacity(0.8),
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber.withOpacity(0.8), width: 1.5)
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(imageUrl),
                        backgroundColor: Colors.black45,
                        onBackgroundImageError: (_, __) {},
                      ),
                    ),
                    title: Text(requestUser.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text("Level ${requestUser.level} ${requestUser.title}", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), shape: BoxShape.circle),
                          child: IconButton(icon: const Icon(Icons.check, color: Colors.greenAccent), tooltip: "Accept", onPressed: () => _handleRequest(requestUid, true)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), shape: BoxShape.circle),
                          child: IconButton(icon: const Icon(Icons.close, color: Colors.redAccent), tooltip: "Decline", onPressed: () => _handleRequest(requestUid, false)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<User>> _getFriendDetails(List<String> friendIds) async {
    final List<User> friends = [];
    for (String id in friendIds) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (doc.exists) friends.add(User.fromFirestore(doc));
    }
    return friends;
  }
}

// --- Tab for adding new friends ---
class _AddFriendView extends StatefulWidget {
  final String uid;
  const _AddFriendView({required this.uid});
  @override
  State<_AddFriendView> createState() => _AddFriendViewState();
}
class _AddFriendViewState extends State<_AddFriendView> {
  final _searchController = TextEditingController();
  Stream<QuerySnapshot>? _searchStream;

  void _searchUsers(String query) {
    if (query.trim().isNotEmpty) {
      setState(() {
        _searchStream = FirebaseFirestore.instance.collection('users')
            .where('name', isEqualTo: query.trim())
            .limit(10)
            .snapshots();
      });
    } else {
      setState(() => _searchStream = null);
    }
  }

  Future<void> _sendFriendRequest(String otherUid) async {
    final firestore = FirebaseFirestore.instance;
    final currentUserRef = firestore.collection('users').doc(widget.uid);
    final otherUserRef = firestore.collection('users').doc(otherUid);

    await currentUserRef.update({'friendRequestsSent': FieldValue.arrayUnion([otherUid])});
    await otherUserRef.update({'friendRequestsReceived': FieldValue.arrayUnion([widget.uid])});

    if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Raven sent! Request delivered.", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search by exact Adventurer Name...",
              hintStyle: TextStyle(color: Colors.grey.shade500),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.amber),
                onPressed: () => _searchUsers(_searchController.text),
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.amber)),
            ),
            onSubmitted: _searchUsers,
          ),
        ),
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
            builder: (context, currentUserSnapshot) {
              if (!currentUserSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
              final currentUser = User.fromFirestore(currentUserSnapshot.data);

              return StreamBuilder<QuerySnapshot>(
                stream: _searchStream,
                builder: (context, snapshot) {
                  if (_searchStream == null) {
                    return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.travel_explore, size: 64, color: Colors.grey.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text("Enter an exact name to find them.", style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                          ],
                        )
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.amber));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No adventurers found with that exact name.", style: TextStyle(color: Colors.grey)));

                  final results = snapshot.data!.docs.where((doc) => doc.id != widget.uid).toList();
                  if (results.isEmpty) return const Center(child: Text("No other adventurers found.", style: TextStyle(color: Colors.grey)));

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final userDoc = results[index];
                      final otherUser = User.fromFirestore(userDoc);
                      final otherUid = userDoc.id;
                      final imageUrl = otherUser.avatarUrl ?? avatarUrls.first;

                      Widget trailingButton;
                      if (currentUser.friends.contains(otherUid)) {
                        trailingButton = _buildStatusBadge("ALLIES", Colors.cyanAccent, Icons.handshake);
                      } else if (currentUser.friendRequestsSent.contains(otherUid)) {
                        trailingButton = _buildStatusBadge("PENDING", Colors.amber, Icons.hourglass_empty);
                      } else if (currentUser.friendRequestsReceived.contains(otherUid)) {
                        trailingButton = _buildStatusBadge("HAS REQUESTED", Colors.purpleAccent, Icons.mail);
                      } else {
                        trailingButton = ElevatedButton.icon(
                          onPressed: () => _sendFriendRequest(otherUid),
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text("Add", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ),
                        );
                      }

                      return Card(
                        color: const Color(0xFF16213E).withOpacity(0.8),
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Colors.white10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundImage: NetworkImage(imageUrl),
                            backgroundColor: Colors.black45,
                            onBackgroundImageError: (_, __) {},
                          ),
                          title: Text(otherUser.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text("Level ${otherUser.level}", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          trailing: trailingButton,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
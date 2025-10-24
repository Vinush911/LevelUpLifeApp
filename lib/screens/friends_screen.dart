import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/avatars.dart';
import 'profile_screen.dart'; // --- NEW: Import ProfileScreen for navigation ---

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
      appBar: AppBar(
        title: const Text("Friends"),
        backgroundColor: const Color(0xFF0F3460),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: "Friends"),
            Tab(icon: Icon(Icons.person_add), text: "Requests"),
            Tab(icon: Icon(Icons.search), text: "Add Friend"),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF1A1A2E),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FriendsListView(uid: widget.uid),
          _RequestsListView(uid: widget.uid),
          _AddFriendView(uid: widget.uid),
        ],
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
        title: Text("Remove $friendName?"),
        content: const Text("Are you sure you want to remove this friend? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text("Remove")),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await currentUserRef.update({'friends': FieldValue.arrayRemove([friendUid])});
      await friendUserRef.update({'friends': FieldValue.arrayRemove([uid])});
      if(context.mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$friendName has been removed from your friends list."), backgroundColor: Colors.orange));
      }
    }
  }

  // --- NEW: Function to navigate to a friend's profile ---
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final user = User.fromFirestore(snapshot.data);

        if (user.friends.isEmpty) {
          return const Center(child: Text("You haven't added any friends yet.", style: TextStyle(color: Colors.grey)));
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: _getFriendDetails(user.friends),
          builder: (context, friendsSnapshot) {
            if (!friendsSnapshot.hasData) return const Center(child: CircularProgressIndicator());
            final friends = friendsSnapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friendDoc = friends[index];
                final friend = User.fromFirestore(friendDoc);
                final imageUrl = friend.avatarUrl ?? avatarUrls.first;

                return Card(
                  color: const Color(0xFF16213E),
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ListTile(
                    // --- MODIFIED: Tap to view profile ---
                    onTap: () => _viewProfile(context, friendDoc.id),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage: NetworkImage(imageUrl),
                      onBackgroundImageError: (_, __) {},
                    ),
                    title: Text(friend.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("Level ${friend.level} - ${friend.userClass ?? 'Adventurer'}", style: const TextStyle(color: Colors.grey)),
                    // --- MODIFIED: Trailing button is now for removing ---
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _removeFriend(context, friendDoc.id, friend.name),
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final user = User.fromFirestore(snapshot.data);

        if (user.friendRequestsReceived.isEmpty) {
          return const Center(child: Text("No pending friend requests.", style: TextStyle(color: Colors.grey)));
        }

        return FutureBuilder<List<User>>(
          future: _getFriendDetails(user.friendRequestsReceived),
          builder: (context, requestsSnapshot) {
            if (!requestsSnapshot.hasData) return const Center(child: CircularProgressIndicator());
            final requests = requestsSnapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final requestUser = requests[index];
                final requestUid = user.friendRequestsReceived[index];
                final imageUrl = requestUser.avatarUrl ?? avatarUrls.first;

                return Card(
                  color: const Color(0xFF16213E),
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(imageUrl),
                      onBackgroundImageError: (_, __) {},
                    ),
                    title: Text(requestUser.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("Level ${requestUser.level}", style: const TextStyle(color: Colors.grey)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.check_circle, color: Colors.greenAccent), tooltip: "Accept", onPressed: () => _handleRequest(requestUid, true)),
                        IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent), tooltip: "Decline", onPressed: () => _handleRequest(requestUid, false)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Friend request sent!"), backgroundColor: Colors.green));
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
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search by exact name...",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () => _searchUsers(_searchController.text),
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onSubmitted: _searchUsers,
          ),
        ),
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
            builder: (context, currentUserSnapshot) {
              if (!currentUserSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              final currentUser = User.fromFirestore(currentUserSnapshot.data);

              return StreamBuilder<QuerySnapshot>(
                stream: _searchStream,
                builder: (context, snapshot) {
                  if (_searchStream == null) return const Center(child: Text("Enter a name to search for other adventurers.", style: TextStyle(color: Colors.grey)));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No users found with that name.", style: TextStyle(color: Colors.grey)));

                  final results = snapshot.data!.docs.where((doc) => doc.id != widget.uid).toList();
                  if (results.isEmpty) return const Center(child: Text("No other users found with that name.", style: TextStyle(color: Colors.grey)));

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final userDoc = results[index];
                      final otherUser = User.fromFirestore(userDoc);
                      final otherUid = userDoc.id;
                      final imageUrl = otherUser.avatarUrl ?? avatarUrls.first;

                      Widget trailingButton;
                      if (currentUser.friends.contains(otherUid)) {
                        trailingButton = const Chip(label: Text("Friends"), backgroundColor: Colors.blue);
                      } else if (currentUser.friendRequestsSent.contains(otherUid)) {
                        trailingButton = const Chip(label: Text("Pending"), backgroundColor: Colors.orange);
                      } else if (currentUser.friendRequestsReceived.contains(otherUid)) {
                        trailingButton = const Chip(label: Text("Check Requests"), backgroundColor: Colors.teal);
                      } else {
                        trailingButton = ElevatedButton(
                          onPressed: () => _sendFriendRequest(otherUid),
                          child: const Text("Add"),
                        );
                      }

                      return Card(
                        color: const Color(0xFF16213E),
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(imageUrl),
                            onBackgroundImageError: (_, __) {},
                          ),
                          title: Text(otherUser.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
}


import 'dart:ui'; // Required for the glass blur effect
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Make sure this filename matches exactly what you named your intro page file!
import 'intro_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // ── Call this method from your home page to show the profile sheet ──
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // Allows it to take up more than half the screen
      backgroundColor: Colors.transparent, // Shows our custom rounded corners
      builder: (context) {
        return DraggableScrollableSheet(
          // Adjust these values to change how much background is visible
          initialChildSize: 0.92, // Starts at 92% of screen height
          minChildSize: 0.5, // Minimum size before it dismisses
          maxChildSize: 0.92, // Maximum size
          builder: (_, scrollController) {
            return _ProfileContent(scrollController: scrollController);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _ProfileContent extends StatefulWidget {
  final ScrollController scrollController;

  const _ProfileContent({required this.scrollController});

  @override
  State<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<_ProfileContent> {
  bool _isDeletingAccount = false;

  // ── SIGN OUT LOGIC ───────────────────────────────────────────────
  Future<void> _handleSignOut(BuildContext context) async {
    try {
      // Sign out of Google
      await GoogleSignIn().signOut();

      // Sign out of Firebase
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      // Close the bottom sheet first
      Navigator.pop(context);

      // Navigate to your IntroPage and clear the navigation history
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const IntroPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  Future<void> _deleteUserFirestoreData(String uid) async {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final tripsSnapshot = await userDocRef.collection('trips').get();

    final WriteBatch batch = FirebaseFirestore.instance.batch();

    for (final doc in tripsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(userDocRef);

    await batch.commit();
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This will delete your saved trips and your Firebase login account. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logged-in user found')),
      );
      return;
    }

    setState(() {
      _isDeletingAccount = true;
    });

    try {
      final uid = user.uid;

      await _deleteUserFirestoreData(uid);

      await user.delete();

      await GoogleSignIn().signOut();

      if (!context.mounted) return;

      Navigator.pop(context);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const IntroPage()),
        (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Delete account FirebaseAuthException: ${e.code}');

      if (!context.mounted) return;

      String message = 'Unable to delete account';

      if (e.code == 'requires-recent-login') {
        message = 'Please sign out, sign in again, then delete your account.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      debugPrint('Delete account error: $e');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete account')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  Widget _buildStatCard({
    required String count,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(User? user) {
    if (user == null) {
      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              count: '0',
              label: 'Saved',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              count: '0',
              label: 'Trips',
            ),
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('trips')
          .snapshots(),
      builder: (context, snapshot) {
        int savedCount = 0;
        int tripsCount = 0;

        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;

          tripsCount = docs.length;

          savedCount = docs.where((doc) {
            final data = doc.data();
            return data['isManualSave'] == true;
          }).length;
        }

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                count: savedCount.toString(),
                label: 'Saved',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                count: tripsCount.toString(),
                label: 'Trips',
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── 1. GET GOOGLE/FIREBASE USER DATA ────────────────────────────
    final User? user = FirebaseAuth.instance.currentUser;

    final String displayName = user?.displayName ?? 'Welcome Traveler';
    final String email = user?.email ?? 'No email linked';
    final String photoUrl = user?.photoURL ??
        'https://ui-avatars.com/api/?name=Guest&background=random';

    // ── 2. FORMAT NAME FOR UI (First name on top, rest on bottom) ───
    String formattedName = displayName;
    if (displayName.contains(' ')) {
      List<String> nameParts = displayName.split(' ');
      formattedName = '${nameParts[0]}\n${nameParts.sublist(1).join(' ')}';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Using ListView with the scrollController enables the drag-to-dismiss feature
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(
            left: 20.0, right: 20.0, top: 12.0, bottom: 40.0),
        children: [
          // ── Drag Handle (The little grey bar at the top) ──────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header (Back & Notification) ──────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () =>
                    Navigator.pop(context), // Closes the bottom sheet
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 22, color: Colors.black),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded,
                    size: 28, color: Colors.black),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Profile Info (NOW USING GOOGLE DATA) ──────────────────
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  image: DecorationImage(
                    image: NetworkImage(photoUrl), // Google Profile Picture
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedName, // Google Display Name
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email, // Google Email Address
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // ── Stats Cards (Saved / Trips) ───────────────────────────
          _buildStatsCards(user),
          const SizedBox(height: 20),

          // ── Import History Card ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Import History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Save links to build your history',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.black, size: 28),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Menu Links (Delete Account & Sign Out) ────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: _isDeletingAccount
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded,
                          color: Colors.black),
                  title: Text(
                    _isDeletingAccount
                        ? 'Deleting Account...'
                        : 'Delete Account',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _isDeletingAccount
                      ? null
                      : () => _handleDeleteAccount(context),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Divider(color: Colors.grey.shade300, height: 1),
                ),
                // ── Sign Out Button ──
                ListTile(
                  leading:
                      Icon(Icons.logout_rounded, color: Colors.red.shade600),
                  title: Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade600,
                    ),
                  ),
                  onTap: () => _handleSignOut(context),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

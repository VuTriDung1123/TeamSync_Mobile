import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/project_model.dart';
import '../../data/repositories/project_repository.dart';
import '../../../../features/auth/data/user_repository.dart';

class ProjectSettingsScreen extends ConsumerStatefulWidget {
  final ProjectModel project;

  const ProjectSettingsScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends ConsumerState<ProjectSettingsScreen> {

  // 🚀 HÀM HIỂN THỊ BẢNG THÊM THÀNH VIÊN
  void _showAddMemberSheet(List<dynamic> currentMemberIds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final usersAsync = ref.watch(usersStreamProvider);
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thêm đồng đội', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.bold)),
              const Gap(16),
              Expanded(
                child: usersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => const Text('Lỗi tải danh sách'),
                  data: (users) {
                    // Lọc những người CHƯA CÓ trong dự án
                    final availableUsers = users.where((u) => !currentMemberIds.contains(u['uid'])).toList();
                    if (availableUsers.isEmpty) return const Center(child: Text('Tất cả mọi người đều đã tham gia dự án!'));

                    return ListView.builder(
                      itemCount: availableUsers.length,
                      itemBuilder: (context, index) {
                        final user = availableUsers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user['avatar'] != null && user['avatar'].toString().isNotEmpty ? NetworkImage(user['avatar']) : null,
                            child: user['avatar'] == null || user['avatar'].toString().isEmpty ? Text((user['name'] ?? '?')[0]) : null,
                          ),
                          title: Text(user['name'] ?? 'Ẩn danh', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                            child: const Text('Thêm'),
                            onPressed: () async {
                              Navigator.pop(context);
                              await ref.read(projectRepositoryProvider).addMemberToProject(widget.project.id, user['uid']);
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã thêm ${user['name']} vào dự án!')));
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final projectColor = Color(int.parse(widget.project.colorHex.replaceFirst('#', '0xFF')));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: projectColor,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text('Cài đặt Dự án', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      // Dùng StreamBuilder để nghe thay đổi realtime của Project (Ví dụ khi vừa add member)
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('projects').doc(widget.project.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final projectData = snapshot.data!.data() as Map<String, dynamic>?;
          if (projectData == null) return const Center(child: Text('Dự án không tồn tại'));

          List<dynamic> memberIds = projectData['memberIds'] ?? [];
          final isOwner = projectData['createdBy'] == currentUserId; // 🚀 Chỉ Owner mới được kick người khác

          return SingleChildScrollView(
            child: Column(
              children: [
                // 1. INFO HEADER
                Container(
                  width: double.infinity,
                  color: projectColor,
                  padding: const EdgeInsets.only(bottom: 30, top: 10),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.dashboard_rounded, size: 40, color: projectColor),
                      ),
                      const Gap(16),
                      Text(projectData['name'] ?? '', style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (projectData['description'] != '')
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Text(projectData['description'], textAlign: TextAlign.center, style: GoogleFonts.nunito(color: Colors.white70)),
                        ),
                    ],
                  ),
                ),
                const Gap(24),

                // 2. THÀNH VIÊN
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${memberIds.length} Thành viên', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 16)),
                      TextButton.icon(
                        onPressed: () => _showAddMemberSheet(memberIds),
                        icon: const Icon(Icons.person_add_rounded, size: 20),
                        label: Text('Thêm người', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                  child: ref.watch(usersStreamProvider).when(
                    loading: () => const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
                    error: (e, st) => const Text('Lỗi tải danh sách'),
                    data: (users) {
                      final projectMembers = users.where((u) => memberIds.contains(u['uid'])).toList();

                      return Column(
                        children: projectMembers.map((user) {
                          final isUserOwner = user['uid'] == projectData['createdBy'];
                          final isMe = user['uid'] == currentUserId;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.primary.withOpacity(0.2),
                              backgroundImage: user['avatar'] != null && user['avatar'].toString().isNotEmpty ? NetworkImage(user['avatar']) : null,
                              child: user['avatar'] == null || user['avatar'].toString().isEmpty ? Text((user['name'] ?? '?')[0]) : null,
                            ),
                            title: Text(isMe ? 'Bạn' : (user['name'] ?? 'Ẩn danh'), style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                            subtitle: isUserOwner ? Text('Trưởng dự án (Owner)', style: GoogleFonts.nunito(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)) : Text('Thành viên', style: GoogleFonts.nunito(fontSize: 12)),
                            // 🚀 Nếu mình là Owner, và người này không phải mình -> Hiện nút Xóa
                            trailing: (isOwner && !isMe)
                                ? IconButton(
                              icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                              onPressed: () async {
                                await ref.read(projectRepositoryProvider).removeMemberFromProject(widget.project.id, user['uid']);
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xóa ${user['name']} khỏi dự án')));
                              },
                            )
                                : null,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                const Gap(40),
              ],
            ),
          );
        },
      ),
    );
  }
}
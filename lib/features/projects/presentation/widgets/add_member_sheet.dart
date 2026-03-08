import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/project_model.dart';
import '../../data/repositories/project_repository.dart';
import '../../../auth/data/user_repository.dart';

class AddMemberSheet extends ConsumerWidget {
  final ProjectModel project;

  const AddMemberSheet({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Giới hạn chiều cao để không bị tràn màn hình
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thêm thành viên', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.bold)),
          const Gap(16),

          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Lỗi: $err')),
              data: (users) {
                // Lọc ra những người CHƯA có trong dự án
                final availableUsers = users.where((u) => !project.memberIds.contains(u['uid'])).toList();

                if (availableUsers.isEmpty) {
                  return Center(
                    child: Text('Tất cả mọi người đều đã tham gia dự án này!',
                      style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: availableUsers.length,
                  itemBuilder: (context, index) {
                    final user = availableUsers[index];
                    final name = user['name'] ?? 'Ẩn danh';
                    final avatar = user['avatar'] ?? '';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary.withOpacity(0.2),
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty ? Icon(Icons.person, color: colorScheme.primary) : null,
                      ),
                      title: Text(name, style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                      subtitle: Text(user['email'] ?? '', style: GoogleFonts.nunito(fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_rounded, size: 28),
                        color: colorScheme.primary,
                        onPressed: () async {
                          // Thêm UID của người này vào danh sách memberIds
                          final newMemberIds = List<String>.from(project.memberIds)..add(user['uid']);

                          // Cập nhật lên Firebase
                          await ref.read(projectRepositoryProvider).updateProject(project.id, {
                            'memberIds': newMemberIds,
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã thêm $name vào dự án!')),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
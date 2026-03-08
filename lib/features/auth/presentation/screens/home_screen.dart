  import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:gap/gap.dart';

  // Các file import cần thiết
  import '../../../../core/utils/push_notification_service.dart';
  import '../../../chat/data/chat_repository.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
  import '../../../chat/presentation/screens/create_group_sheet.dart';
import '../../../projects/data/models/task_model.dart';
  import '../../../projects/presentation/project_controller.dart';
  import '../../../projects/presentation/widgets/create_project_sheet.dart';
  import '../../data/user_repository.dart'; // Nguồn cấp usersStreamProvider

  class HomeScreen extends ConsumerWidget {
    const HomeScreen({super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      Future.microtask(() => PushNotificationService().initNotifications());
      final colorScheme = Theme.of(context).colorScheme;

      // Bọc toàn bộ trong DefaultTabController để tạo 2 Tab vuốt qua lại được
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: const Color(0xFFFFF5F7), // Vẫn giữ tone màu nhẹ nhàng của bạn
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'TeamSync',
              style: GoogleFonts.nunito(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
                fontSize: 26,
                letterSpacing: 1.2,
              ),
            ),
            actions: [
              // Nút Thêm Dự Án (Bật BottomSheet)
              IconButton(
                icon: const Icon(Icons.add_box_rounded, color: Colors.black87),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true, // Cho phép khung tự nâng lên khi có bàn phím ảo
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (context) => const CreateProjectSheet(),
                  );
                },
              ),
              // Nút Tìm kiếm đồng đội
              IconButton(
                icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black87),
                onPressed: () => context.push('/search'),
              ),
              // Nút Cài đặt hồ sơ
              IconButton(
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primary.withOpacity(0.2),
                  child: const Icon(Icons.settings_rounded, size: 18, color: Colors.black87),
                ),
                onPressed: () => context.push('/settings'),
              ),
              // Nút Tạo Nhóm Chat MỚI
              IconButton(
                  icon: const Icon(Icons.group_add_rounded, color: Colors.black87),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const CreateGroupSheet(),
                    );
                  },
              ),
              const Gap(8),
            ],
            // THANH MENU CHUYỂN TAB
            bottom: TabBar(
              labelColor: colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: colorScheme.primary,
              labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16),
              tabs: const [
                Tab(text: 'Việc của tôi',),
                Tab(text: 'Dự án'),
                Tab(text: 'Đồng đội'),
              ],
            ),
          ),

          // NỘI DUNG 2 TAB
          body: TabBarView(
            children: [
              // Nội dung: Danh sách Task của tôi
              _buildMyTasksTab(context, ref, colorScheme),
              // Nội dung: Danh sách Dự án (Vừa code xong)
              _buildProjectsTab(context, ref, colorScheme),
              // Nội dung: Danh sách Đồng đội (Đoạn code nguyên bản của bạn)
              _buildTeamTab(context, ref, colorScheme),
            ],
          ),
        ),
      );
    }

    // ==========================================
    // WIDGET CON 1: TAB QUẢN LÝ DỰ ÁN
    // ==========================================
    Widget _buildProjectsTab(BuildContext context, WidgetRef ref, ColorScheme colorScheme) {
      final projectsAsync = ref.watch(userProjectsProvider);

      return projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Lỗi tải dự án: $err')),
        data: (projects) {
          if (projects.isEmpty) {
            return Center(
              child: Text(
                'Chưa có dự án nào.\nBấm icon [+] góc trên để tạo mới nhé! 🌸',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              // Đọc mã màu từ Firebase để tô điểm cho Card
              final projectColor = Color(int.parse(project.colorHex.replaceFirst('#', '0xFF')));

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    context.push('/project-detail', extra: project);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: projectColor.withOpacity(0.3), width: 2),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16, height: 16,
                              decoration: BoxDecoration(color: projectColor, shape: BoxShape.circle),
                            ),
                            const Gap(12),
                            Expanded(
                              child: Text(
                                  project.name,
                                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                              ),
                            ),
                            Icon(Icons.more_horiz_rounded, color: Colors.grey.shade400),
                          ],
                        ),
                        if (project.description.isNotEmpty) ...[
                          const Gap(8),
                          Text(
                              project.description,
                              style: GoogleFonts.nunito(color: Colors.grey.shade600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis
                          ),
                        ],
                        const Gap(16),
                        Row(
                          children: [
                            Icon(Icons.group_outlined, size: 18, color: Colors.grey.shade500),
                            const Gap(6),
                            Text(
                                '${project.memberIds.length} thành viên',
                                style: GoogleFonts.nunito(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w600)
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    // ==========================================
    // WIDGET CON 2: TAB ĐỒNG ĐỘI (HỘP THƯ INBOX)
    // ==========================================
    Widget _buildTeamTab(BuildContext context, WidgetRef ref, ColorScheme colorScheme) {
      final chatRoomsAsync = ref.watch(userChatRoomsProvider);
      final usersAsync = ref.watch(usersStreamProvider);
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      return chatRoomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Lỗi tải danh sách: $err')),
        data: (chatRooms) {
          if (chatRooms.isEmpty) return Center(child: Text('Chưa có cuộc trò chuyện nào 🌸', style: GoogleFonts.nunito(color: Colors.grey)));

          return usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => const SizedBox(),
              data: (users) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: chatRooms.length,
                  itemBuilder: (context, index) {
                    final room = chatRooms[index];
                    final isGroup = room['isGroup'] ?? false;

                    String title = '';
                    String avatarUrl = '';
                    String targetId = '';

                    // 🚀 XỬ LÝ HIỂN THỊ CHUNG CHO NHÓM & 1-1
                    if (isGroup) {
                      title = room['groupName'] ?? 'Nhóm';
                      avatarUrl = room['groupAvatar'] ?? '';
                      targetId = room['roomId'];
                    } else {
                      List<dynamic> members = room['users'] ?? [];
                      String otherUid = members.firstWhere((id) => id != currentUserId, orElse: () => '');
                      targetId = otherUid;
                      final otherUser = users.firstWhere((u) => u['uid'] == otherUid, orElse: () => <String, dynamic>{});
                      title = otherUser['name'] ?? 'Ẩn danh';
                      avatarUrl = otherUser['avatar'] ?? '';
                    }

                    String lastMessage = room['lastMessage'] ?? 'Bắt đầu cuộc trò chuyện mới';
                    bool isUnread = !List<String>.from(room['lastMessageReadBy'] ?? []).contains(currentUserId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: colorScheme.primary.withOpacity(0.2),
                          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl.isEmpty ? (isGroup ? Icon(Icons.group, color: colorScheme.primary) : Text(title.isNotEmpty ? title[0].toUpperCase() : '?')) : null,
                        ),
                        title: Text(title, style: GoogleFonts.nunito(fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold, fontSize: 16, color: Colors.black87)),
                        subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(fontSize: 14, fontWeight: isUnread ? FontWeight.w900 : FontWeight.normal, color: isUnread ? Colors.black : Colors.grey.shade600)
                        ),
                        trailing: isUnread ? Container(width: 12, height: 12, decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle)) : null,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              receiverId: targetId,
                              receiverName: title,
                              receiverAvatar: avatarUrl,
                              isGroup: isGroup, // 🚀 TRUYỀN CỜ isGroup SANG CHAT SCREEN
                            ),
                          ));
                        },
                      ),
                    );
                  },
                );
              }
          );
        },
      );
    }

    // ==========================================
    // WIDGET CON 3: TAB VIỆC CỦA TÔI
    // ==========================================
    Widget _buildMyTasksTab(BuildContext context, WidgetRef ref, ColorScheme colorScheme) {
      final myTasksAsync = ref.watch(myActiveTasksProvider);

      return myTasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt_rounded, size: 64, color: colorScheme.primary.withOpacity(0.5)),
                  const Gap(16),
                  Text(
                    'Tuyệt vời! Bạn đã hoàn thành\nmọi công việc được giao 🎉',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isOverdue = task.deadline != null && task.deadline!.isBefore(DateTime.now());

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isOverdue ? Colors.red.shade200 : colorScheme.primary.withOpacity(0.1)),
                ),
                elevation: 0,
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: task.status == TaskStatus.inProgress
                          ? Colors.orange.shade100
                          : Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      task.status == TaskStatus.inProgress ? Icons.timelapse_rounded : Icons.list_alt_rounded,
                      color: task.status == TaskStatus.inProgress ? Colors.orange.shade700 : Colors.blue.shade700,
                    ),
                  ),
                  title: Text(task.title, style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    task.deadline != null ? 'Hạn: ${task.deadline!.day}/${task.deadline!.month}' : 'Không có hạn',
                    style: GoogleFonts.nunito(color: isOverdue ? Colors.red : Colors.grey.shade600, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () {
                    // TODO: Bấm vào mở popup xem chi tiết task (Hoặc nhảy vào Dự án)
                  },
                ),
              );
            },
          );
        },
      );
    }
  }
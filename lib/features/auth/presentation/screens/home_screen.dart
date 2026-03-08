  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:gap/gap.dart';

  // Các file import cần thiết
  import '../../../../core/utils/push_notification_service.dart';
  import '../../../chat/presentation/screens/chat_screen.dart';
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
    // WIDGET CON 2: TAB DANH SÁCH ĐỒNG ĐỘI
    // ==========================================
    Widget _buildTeamTab(BuildContext context, WidgetRef ref, ColorScheme colorScheme) {
      final usersAsync = ref.watch(usersStreamProvider);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Text(
              'Sẵn sàng kết nối\nvà làm việc cùng nhau! ✨',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))
                ],
              ),
              child: usersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Lỗi tải danh sách: $err')),
                data: (users) {
                  if (users.isEmpty) {
                    return Center(
                      child: Text(
                        'Chưa có ai ở đây cả.\nHãy mời thêm bạn bè nhé! 🌸',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final name = user['name'] ?? 'Ẩn danh';
                      final email = user['email'] ?? '';
                      final uid = user['uid'] ?? '';
                      final avatar = user['avatar'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F7).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor: colorScheme.primary.withOpacity(0.2),
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty
                                ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: GoogleFonts.nunito(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            )
                                : null,
                          ),
                          title: Text(name, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)),
                          subtitle: Text(email, style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade600)),
                          trailing: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  receiverId: uid,
                                  receiverName: name,
                                  receiverAvatar: avatar,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
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
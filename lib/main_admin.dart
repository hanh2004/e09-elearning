import 'app/app_portal.dart';
import 'app/bootstrap.dart';
import 'app/elearning_app.dart';
import 'screens/admin/admin_home_screen.dart';

Future<void> main() => bootstrap(
  ElearningApp(
    portal: AppPortal.admin,
    homeBuilder: (_) => const AdminHomeScreen(),
  ),
);

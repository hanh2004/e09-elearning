import 'app/app_portal.dart';
import 'app/bootstrap.dart';
import 'app/elearning_app.dart';
import 'models/user_arguments.dart';
import 'screens/user/user_main_layout.dart';

Future<void> main() => bootstrap(
  ElearningApp(
    portal: AppPortal.user,
    homeBuilder: (data) => UserMainLayout(
      args: UserArguments(
        userId: data['id'].toString(),
        userName: data['name']?.toString() ?? data['username'].toString(),
        email: data['email']?.toString() ?? '',
      ),
    ),
  ),
);

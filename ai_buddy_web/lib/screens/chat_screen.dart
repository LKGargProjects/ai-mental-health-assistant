import 'package:provider/provider.dart';

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Prefetch session to ensure first message is saved
    Future.microtask(
      () => Provider.of<ChatProvider>(context, listen: false).prefetchSession(),
    );
  }
}

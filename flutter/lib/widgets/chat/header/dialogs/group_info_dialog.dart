import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/api_service.dart';

class GroupInfoDialog extends StatelessWidget {
  final String roomId;
  final String roomName;

  const GroupInfoDialog({
    Key? key,
    required this.roomId,
    required this.roomName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.55;

    return AlertDialog(
      title: const Text('Group Info'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $roomName', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Members:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: maxHeight,
              child: FutureBuilder<Map<String, dynamic>>(
                future: context.read<ApiService>().getRoomMembers(roomId).run().then((res) => res.fold((l) => throw l, (r) => r)),
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Text('No members found');
                  }
                  final members = (snapshot.data!['participants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                  return ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (ctx, idx) {
                      final member = members[idx];
                      final isCreator = member['is_creator'] ?? false;
                      return ListTile(
                        title: Text('${member['first_name']?.isEmpty ?? true ? member['username'] : '${member['first_name']} ${member['last_name']}'}'.trim()),
                        subtitle: Text('@${member['username']}'),
                        trailing: isCreator
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(12)),
                                child: const Text('Creator', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

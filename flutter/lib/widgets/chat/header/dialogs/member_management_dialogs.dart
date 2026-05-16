import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/friend.dart';
import '../../../../providers/friend_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/api_service.dart';

class AddMemberDialog extends StatelessWidget {
  final List<Friend> candidates;

  const AddMemberDialog({Key? key, required this.candidates}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.55;

    return AlertDialog(
      title: const Text('Add Member'),
      content: SizedBox(
        width: double.maxFinite,
        child: candidates.isEmpty
            ? const Text('No available friends to add')
            : SizedBox(
                height: maxHeight,
                child: ListView.builder(
                  itemCount: candidates.length,
                  itemBuilder: (ctx, index) {
                    final friend = candidates[index];
                    return ListTile(
                      onTap: () => Navigator.pop(context, friend),
                      leading: CircleAvatar(
                        radius: 20,
                        child: Text(friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : '?'),
                      ),
                      title: Text(friend.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('@${friend.username}'),
                    );
                  },
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}

class RemoveMemberDialog extends StatelessWidget {
  final List<Map<String, dynamic>> members;

  const RemoveMemberDialog({Key? key, required this.members}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.55;

    return AlertDialog(
      title: const Text('Remove Member'),
      content: SizedBox(
        width: double.maxFinite,
        child: SizedBox(
          height: maxHeight,
          child: ListView.builder(
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
                onTap: isCreator ? null : () => Navigator.pop(context, member['id'] as int),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}

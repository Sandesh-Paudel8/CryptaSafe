import 'package:flutter/material.dart';

class DecoyVaultScreen extends StatelessWidget {
  const DecoyVaultScreen({Key? key}) : super(key: key);

  static const _fakeFiles = [
    {'name': 'holiday_photos.jpg', 'size': '3.2 MB', 'icon': Icons.image},
    {'name': 'recipe_notes.txt', 'size': '12 KB', 'icon': Icons.description},
    {'name': 'grocery_list.pdf', 'size': '45 KB', 'icon': Icons.picture_as_pdf},
    {'name': 'birthday_wishes.txt', 'size': '4 KB', 'icon': Icons.description},
    {'name': 'travel_plans.docx', 'size': '89 KB', 'icon': Icons.description},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('CryptaSafe Vault'),
        backgroundColor: Colors.grey[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Stored files',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _fakeFiles.length,
                itemBuilder: (context, i) {
                  final file = _fakeFiles[i];
                  return Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: Icon(file['icon'] as IconData,
                          color: Colors.blueGrey[300]),
                      title: Text(file['name'] as String,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(file['size'] as String,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12)),
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('File preview not available')),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

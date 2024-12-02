import 'package:flutter/material.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.initializeDatabase();
  runApp(const CardOrganizerApp());
}

class CardOrganizerApp extends StatelessWidget {
  const CardOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Organizer App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FoldersScreen(),
    );
  }
}

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  _FoldersScreenState createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  late Future<List<Map<String, dynamic>>> _folders;

  @override
  void initState() {
    super.initState();
    _folders = _loadFolders();
  }

  Future<List<Map<String, dynamic>>> _loadFolders() async {
    await _databaseHelper.initializeDatabase();
    return _databaseHelper.queryAllFolders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Card Folders')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _folders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No folders found.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final folder = snapshot.data![index];
              int folderId = folder[DatabaseHelper.folderId];

              return FutureBuilder<String?>(
                future: _databaseHelper.getFirstCardImage(folderId),
                builder: (context, imageSnapshot) {
                  return ListTile(
                    leading: imageSnapshot.connectionState == ConnectionState.waiting
                        ? const CircularProgressIndicator()
                        : imageSnapshot.hasData && imageSnapshot.data != null
                            ? Image.asset(imageSnapshot.data!, width: 50)
                            : const Icon(Icons.folder, size: 50),
                    title: Text(folder[DatabaseHelper.folderName]),
                    subtitle: FutureBuilder<int>(
                      future: _databaseHelper.getCardCount(folderId),
                      builder: (context, countSnapshot) {
                        if (countSnapshot.connectionState == ConnectionState.waiting) {
                          return const Text('Loading count...');
                        }
                        return Text('${countSnapshot.data ?? 0} cards');
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CardsScreen(folderId: folderId),
                        ),
                      ).then((_) {
                        // Refresh the folders screen when returning from cards screen
                        setState(() {
                          _folders = _loadFolders();
                        });
                      });
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class CardsScreen extends StatefulWidget {
  final int folderId;

  const CardsScreen({super.key, required this.folderId});

  @override
  _CardsScreenState createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  late Future<List<Map<String, dynamic>>> _cards;

  @override
  void initState() {
    super.initState();
    _cards = _loadCards();
  }

  Future<List<Map<String, dynamic>>> _loadCards() async {
    await _databaseHelper.initializeDatabase();
    return _databaseHelper.queryCardsByFolder(widget.folderId);
  }

  void _showAddCardDialog() async {
    final availableCards = await _databaseHelper.getAvailableCards();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Card to Folder'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableCards.length,
              itemBuilder: (context, index) {
                final card = availableCards[index];
                return ListTile(
                  leading: Image.asset(
                    card[DatabaseHelper.cardImageUrl],
                    width: 40,
                  ),
                  title: Text('${card[DatabaseHelper.cardName]} of ${card[DatabaseHelper.cardSuit]}'),
                  onTap: () async {
                    await _databaseHelper.assignCardToFolder(
                      card[DatabaseHelper.cardId],
                      widget.folderId,
                    );
                    Navigator.pop(context);
                    setState(() {
                      _cards = _loadCards();
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(int cardId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Card'),
          content: const Text('Are you sure you want to remove this card from the folder?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _databaseHelper.updateCard({
                  DatabaseHelper.cardId: cardId,
                  DatabaseHelper.foreignFolderId: null,
                });
                if (!mounted) return;
                Navigator.pop(context);
                setState(() {
                  _cards = _loadCards();
                });
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Map<String, dynamic>?>(
          future: _databaseHelper.queryFolder(widget.folderId),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text('${snapshot.data![DatabaseHelper.folderName]} Cards');
            }
            return const Text('Cards');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddCardDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cards,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No cards in this folder.'));
          }

          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final card = snapshot.data![index];
              return Card(
                elevation: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Image.asset(
                        card[DatabaseHelper.cardImageUrl],
                        fit: BoxFit.contain,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '${card[DatabaseHelper.cardName]} of ${card[DatabaseHelper.cardSuit]}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteConfirmation(card[DatabaseHelper.cardId]),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
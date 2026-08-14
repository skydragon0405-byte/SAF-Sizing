import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const SAFParadeApp());
}

class SAFParadeApp extends StatelessWidget {
  const SAFParadeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAF Parade Sizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xff0047ab), // Cobalt Blue Primary
        colorScheme: const ColorScheme.dark(
          primary: Color(0xff0047ab), // Cobalt Blue
          secondary: Color(0xff00ffff), // Cyan highlight for military precision
          background: Color(0xff0b132b), // Deep Navy/Cobalt Dark background
          surface: Color(0xff1c2541), // Card Background
        ),
        scaffoldBackgroundColor: const Color(0xff0b132b),
      ),
      home: const ParadeSizerScreen(),
    );
  }
}

class Soldier {
  final int? id;
  final String rank;
  final String name;
  final double height;
  final bool isPresent;

  Soldier({this.id, required this.rank, required this.name, required this.height, this.isPresent = true});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rank': rank,
      'name': name,
      'height': height,
      'isPresent': isPresent ? 1 : 0,
    };
  }

  factory Soldier.fromMap(Map<String, dynamic> map) {
    return Soldier(
      id: map['id'],
      rank: map['rank'],
      name: map['name'],
      height: map['height'],
      isPresent: map['isPresent'] == 1,
    );
  }
}

class ParadeSizerScreen extends StatefulWidget {
  const ParadeSizerScreen({Key? key}) : super(key: key);

  @override
  _ParadeSizerScreenState createState() => _ParadeSizerScreenState();
}

class _ParadeSizerScreenState extends State<ParadeSizerScreen> {
  List<Soldier> _soldiers = [];
  int _selectedRows = 3;
  Database? _database;
  bool _isLoading = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  String _selectedRank = 'REC';

  final List<String> _ranks = ['REC', 'PTE', 'LCP', 'CPL', 'CFC', '3SG', '2SG', '1SG', 'SSG', 'MSG', 'WO', 'MAJ'];

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  // Initialize SQLite Local Data Storage Function
  Future<void> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'saf_parade.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE soldiers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rank TEXT,
            name TEXT,
            height REAL,
            isPresent INTEGER
          )
        ''');
      },
    );
    _loadSoldiers();
  }

  // Fetch Saved Roster from Local Memory
  Future<void> _loadSoldiers() async {
    if (_database == null) return;
    final List<Map<String, dynamic>> maps = await _database!.query('soldiers');
    
    setState(() {
      _soldiers = maps.map((map) => Soldier.fromMap(map)).toList();
      _isLoading = false;
    });
  }

  // Save new record to memory
  Future<void> _addSoldier() async {
    if (_formKey.currentState!.validate() && _database != null) {
      final newSoldier = Soldier(
        rank: _selectedRank,
        name: _nameController.text,
        height: double.parse(_heightController.text),
        isPresent: true,
      );

      await _database!.insert('soldiers', newSoldier.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      _nameController.clear();
      _heightController.clear();
      _loadSoldiers();
    }
  }

  // Toggle Attendance Switch
  Future<void> _toggleAttendance(Soldier soldier) async {
    if (_database == null) return;
    final updatedSoldier = Soldier(
      id: soldier.id,
      rank: soldier.rank,
      name: soldier.name,
      height: soldier.height,
      isPresent: !soldier.isPresent,
    );

    await _database!.update(
      'soldiers',
      updatedSoldier.toMap(),
      where: 'id = ?',
      whereArgs: [soldier.id],
    );
    _loadSoldiers();
  }

  // Delete Record from Database Permanently
  Future<void> _deleteSoldier(int id) async {
    if (_database == null) return;
    await _database!.delete('soldiers', where: 'id = ?', whereArgs: [id]);
    _loadSoldiers();
  }

  // SAF Parade Sizing Logic Filtered by Active Attendance
  List<List<Soldier?>> _generateParadeGrid() {
    // ONLY arrange personnel who are marked as PRESENT
    List<Soldier> sorted = _soldiers.where((s) => s.isPresent).toList();
    sorted.sort((a, b) => b.height.compareTo(a.height)); // Tallest first

    int totalSoldiers = sorted.length;
    if (totalSoldiers == 0) return [];

    int rows = _selectedRows;
    int files = (totalSoldiers / rows).ceil();

    List<List<Soldier?>> grid = List.generate(rows, (_) => List.filled(files, null));

    // Mapping Flanking Sequences (Tallest out to Shortest Center)
    List<int> fileOrder = [];
    int left = 0;
    int right = files - 1;
    bool toggle = true;

    while (left <= right) {
      if (toggle) {
        fileOrder.add(left);
        left++;
      } else {
        fileOrder.add(right);
        right--;
      }
      toggle = !toggle;
    }

    int soldierIdx = 0;
    for (int r = 0; r < rows; r++) {
      for (int f = 0; f < files; f++) {
        if (soldierIdx < totalSoldiers) {
          int targetedFile = fileOrder[f];
          grid[r][targetedFile] = sorted[soldierIdx];
          soldierIdx++;
        }
      }
    }
    return grid;
  }

  // Export Balanced Sizing Structure to CSV
  Future<void> _exportToCSV() async {
    var grid = _generateParadeGrid();
    if (grid.isEmpty) return;

    int rows = grid.length;
    int files = grid[0].length;

    String csvContent = "SAF COBALT PARADE SIZING GRID\n";
    csvContent += "File 1 is Right Flank, Last File is Left Flank.\n\n";

    for (int r = 0; r < rows; r++) {
      csvContent += "Row ${r + 1},";
      List<String> rowCells = [];
      for (int f = 0; f < files; f++) {
        var s = grid[r][f];
        rowCells.add(s != null ? "${s.rank} ${s.name} (${s.height.toStringAsFixed(0)}cm)" : "EMPTY");
      }
      csvContent += rowCells.join(",") + "\n";
    }

    csvContent += "\n\nMASTER RECORD ROSTER\n";
    csvContent += "Rank,Name,Height (cm),Status\n";
    for (var s in _soldiers) {
      csvContent += "${s.rank},${s.name},${s.height},${s.isPresent ? 'Present' : 'Absent'}\n";
    }

    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/saf_cobalt_parade.csv');
      await file.writeAsString(csvContent);
      await Share.shareXFiles([XFile(file.path)], text: 'SAF Cobalt Parade Sizing Export');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    var grid = _generateParadeGrid();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SAF Parade Sizer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xff0047ab),
        actions: [
          IconButton(icon: const Icon(Icons.download, color: Color(0xff00ffff)), tooltip: 'Export CSV Layout', onPressed: _exportToCSV)
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xff00ffff)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Control input panel card
                  Card(
                    color: const Color(0xff1c2541),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xff0047ab), width: 1.5)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Text('Add Platoon Personnel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff00ffff))),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                DropdownButton<String>(
                                  value: _selectedRank,
                                  dropdownColor: const Color(0xff1c2541),
                                  onChanged: (val) => setState(() => _selectedRank = val!),
                                  items: _ranks.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: Colors.white60)),
                                    validator: (val) => val!.isEmpty ? 'Enter Name' : null,
                                  ),
                                ),
                              ],
                            ),
                            TextFormField(
                              controller: _heightController,
                              keyboardType: TextInputType.number,

import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, TextInput, TouchableOpacity, ScrollView, FlatList, Switch } from 'react-native';
import * as FileSystem from 'expo-file-system';
import * as Sharing from 'expo-sharing';
import AsyncStorage from '@react-native-async-storage/async-storage';

export default function App() {
  const [soldiers, setSoldiers] = useState([]);
  const [rank, setRank] = useState('REC');
  const [name, setName] = useState('');
  const [height, setHeight] = useState('');
  const [rows, setRows] = useState(3);

  // Load Saved Data on Launch
  useEffect(() => {
    loadData();
  }, []);

  const saveData = async (currentList) => {
    try {
      await AsyncStorage.setItem('@soldiers_list', JSON.stringify(currentList));
    } catch (e) {
      console.log('Error saving data', e);
    }
  };

  const loadData = async () => {
    try {
      const jsonValue = await AsyncStorage.getItem('@soldiers_list');
      if (jsonValue != null) {
        setSoldiers(JSON.parse(jsonValue));
      }
    } catch (e) {
      console.log('Error loading data', e);
    }
  };

  const addSoldier = () => {
    if (!name || !height) return;
    const newSoldier = {
      id: Date.now().toString(),
      rank: rank,
      name: name,
      height: parseFloat(height),
      isPresent: true
    };
    const updated = [...soldiers, newSoldier];
    setSoldiers(updated);
    saveData(updated);
    setName('');
    setHeight('');
  };

  const toggleAttendance = (id) => {
    const updated = soldiers.map(s => s.id === id ? { ...s, isPresent: !s.isPresent } : s);
    setSoldiers(updated);
    saveData(updated);
  };

  const deleteSoldier = (id) => {
    const updated = soldiers.filter(s => s.id !== id);
    setSoldiers(updated);
    saveData(updated);
  };

  // SAF Parade Sizing Algorithm
  const generateParadeGrid = () => {
    let presentSoldiers = soldiers.filter(s => s.isPresent);
    presentSoldiers.sort((a, b) => b.height - a.height); // Tallest first

    if (presentSoldiers.length === 0) return [];

    let files = Math.ceil(presentSoldiers.length / rows);
    let grid = Array(rows).fill(null).map(() => Array(files).fill(null));

    let fileOrder = [];
    let left = 0;
    let right = files - 1;
    let toggle = true;

    while (left <= right) {
      if (toggle) { fileOrder.push(left); left++; }
      else { fileOrder.push(right); right--; }
      toggle = !toggle;
    }

    let idx = 0;
    for (let r = 0; r < rows; r++) {
      for (let f = 0; f < files; f++) {
        if (idx < presentSoldiers.length) {
          let targetedFile = fileOrder[f];
          grid[r][targetedFile] = presentSoldiers[idx];
          idx++;
        }
      }
    }
    return grid;
  };

  const exportCSV = async () => {
    const grid = generateParadeGrid();
    if (grid.length === 0) return;

    let csvContent = "SAF COBALT PARADE SIZING GRID\nFile 1 is Right Flank, Last File is Left Flank.\n\n";
    grid.forEach((row, rIdx) => {
      csvContent += `Row ${rIdx + 1},` + row.map(s => s ? `${s.rank} ${s.name} (${s.height}cm)` : "EMPTY").join(",") + "\n";
    });

    csvContent += "\n\nMASTER RECORD ROSTER\nRank,Name,Height (cm),Status\n";
    soldiers.forEach(s => {
      csvContent += `${s.rank},${s.name},${s.height},${s.isPresent ? 'Present' : 'Absent'}\n`;
    });

    const fileUri = FileSystem.documentDirectory + "saf_cobalt_parade.csv";
    await FileSystem.writeAsStringAsync(fileUri, csvContent, { encoding: FileSystem.EncodingType.UTF8 });
    await Sharing.shareAsync(fileUri);
  };

  const grid = generateParadeGrid();

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.title}>SAF Parade Sizer (Cobalt)</Text>
      
      {/* Input Section */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Add Platoon Personnel</Text>
        <TextInput style={styles.input} placeholder="Name" placeholderTextColor="#aaa" value={name} onChangeText={setName} />
        <TextInput style={styles.input} placeholder="Height (cm)" placeholderTextColor="#aaa" keyboardType="numeric" value={height} onChangeText={setHeight} />
        <TouchableOpacity style={styles.button} onPress={addSoldier}>
          <Text style={styles.buttonText}>Save to Parade</Text>
        </TouchableOpacity>
      </View>

      {/* Row Configuration */}
      <View style={styles.rowConfig}>
        <Text style={styles.label}>Formation Rows: {rows}</Text>
        <View style={styles.flexRow}>
          {[2, 3, 4].map(r => (
            <TouchableOpacity key={r} style={[styles.inlineBtn, rows === r && styles.activeInlineBtn]} onPress={() => setRows(r)}>
              <Text style={styles.buttonText}>{r} Rows</Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Export Button */}
      <TouchableOpacity style={[styles.button, { backgroundColor: '#00ffff', marginVertical: 10 }]} onPress={exportCSV}>
        <Text style={[styles.buttonText, { color: '#0b132b' }]}>Export CSV Layout</Text>
      </TouchableOpacity>

      {/* Parade Grid Visualizer */}
      <Text style={styles.sectionTitle}>Parade Square Grid Preview</Text>
      <ScrollView horizontal style={styles.gridScroll}>
        <View style={styles.gridContainer}>
          {grid.map((row, rIdx) => (
            <View key={rIdx} style={styles.gridRow}>
              {row.map((s, fIdx) => (
                <View key={fIdx} style={[styles.gridCell, s && styles.gridCellFilled]}>
                  {s ? (
                    <>
                      <Text style={styles.cellText} numberOfLines={1}>{s.rank} {s.name}</Text>
                      <Text style={styles.cellHeight}>{s.height} cm</Text>
                    </>
                  ) : (
                    <Text style={{ color: '#444' }}>-</Text>
                  )}
                </View>
              ))}
            </View>
          ))}
        </View>
      </ScrollView>

      {/* Attendance List */}
      <Text style={styles.sectionTitle}>Platoon Master Nominal Roll</Text>
      {soldiers.map(item => (
        <View key={item.id} style={styles.soldierItem}>
          <Switch value={item.isPresent} onValueChange={() => toggleAttendance(item.id)} trackColor={{ true: '#0047ab' }} thumbColor="#00ffff" />
          <Text style={[styles.soldierText, !item.isPresent && styles.absentText]}>{item.rank} {item.name} ({item.height}cm)</Text>
          <TouchableOpacity onPress={() => deleteSoldier(item.id)}>
            <Text style={{ color: '#ff4444', fontWeight: 'bold' }}>Delete</Text>
          </TouchableOpacity>
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0b132b', padding: 16, paddingTop: 40 },
  title: { fontSize: 22, fontWeight: 'bold', color: '#fff', textAlign: 'center', marginBottom: 20 },
  card: { backgroundColor: '#1c2541', padding: 16, borderRadius: 12, borderWidth: 1.5, borderColor: '#0047ab', marginBottom: 15 },
  cardTitle: { fontSize: 16, fontWeight: 'bold', color: '#00ffff', marginBottom: 12, textAlign: 'center' },
  input: { backgroundColor: '#0b132b', color: '#fff', padding: 10, borderRadius: 6, marginBottom: 10, borderWidth: 1, borderColor: '#334155' },
  button: { backgroundColor: '#0047ab', padding: 12, borderRadius: 6, alignItems: 'center' },
  buttonText: { color: '#fff', fontWeight: 'bold' },
  rowConfig: { marginVertical: 10 },
  label: { color: '#fff', marginBottom: 5, fontWeight: 'bold' },
  flexRow: { flexDirection: 'row', justifyContent: 'space-between' },
  inlineBtn: { backgroundColor: '#1c2541', padding: 10, borderRadius: 6, flex: 1, marginHorizontal: 2, alignItems: 'center' },
  activeInlineBtn: { backgroundColor: '#0047ab', borderWidth: 1, borderColor: '#00ffff' },
  sectionTitle: { color: '#00ffff', fontSize: 15, fontWeight: 'bold', marginVertical: 10 },
  gridScroll: { backgroundColor: '#000', padding: 10, borderRadius: 8, borderWidth: 1, borderColor: '#0047ab', marginBottom: 15 },
  gridContainer: { flexDirection: 'column' },
  gridRow: { flexDirection: 'row' },
  gridCell: { width: 95, height: 60, justifyContent: 'center', alignItems: 'center', margin: 4, borderWidth: 0.5, borderColor: '#333', borderRadius: 4 },
  gridCellFilled: { backgroundColor: 'rgba(0,71,171,0.8)', borderColor: '#00ffff', borderWidth: 1 },
  cellText: { color: '#fff', fontSize: 10, fontWeight: 'bold', paddingHorizontal: 2 },
  cellHeight: { color: '#00ffff', fontSize: 9 },
  soldierItem: { flexDirection: 'row', backgroundColor: '#1c2541', padding: 12, borderRadius: 8, alignItems: 'center', justifyContent: 'space-between', marginVertical: 4 },
  soldierText: { color: '#fff', fontWeight: 'bold', flex: 1, marginLeft: 10 },
  absentText: { color: '#555', textDecorationLine: 'line-through' }
});

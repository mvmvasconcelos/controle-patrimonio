import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/patrimonio.dart';
import '../database/hive_database.dart';

class PatrimonioProvider with ChangeNotifier {
  List<Patrimonio> _patrimonios = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastSync;

  // Getters
  List<Patrimonio> get patrimonios => _patrimonios;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastSync => _lastSync;
  bool get hasData => _patrimonios.isNotEmpty;

  // Configurações do backend
  static const String baseUrl = 'http://128.1.1.49:6090';

  // Carregar dados do Hive na inicialização
  Future<void> loadLocalData() async {
    try {
      _patrimonios = HiveDatabase.getAllPatrimonios();
      _lastSync = HiveDatabase.getSetting<DateTime>('last_sync');
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao carregar dados locais: $e';
      notifyListeners();
    }
  }

  // Sincronizar com o backend
  Future<void> syncWithBackend() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$baseUrl/patrimonio'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final patrimonios = data.map((json) => Patrimonio.fromJson(json)).toList();

        // Salvar no banco local
        await HiveDatabase.savePatrimonioData(patrimonios);
        _patrimonios = patrimonios;
        _lastSync = DateTime.now();

        // Salvar timestamp da sincronização
        await HiveDatabase.setSetting('last_sync', _lastSync!);

        notifyListeners();
      } else {
        throw Exception('Erro na sincronização: ${response.statusCode}');
      }
    } catch (e) {
      _error = 'Erro na sincronização: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Buscar patrimônio por número
  Patrimonio? getPatrimonioByNumero(String numero) {
    return HiveDatabase.getPatrimonioByNumero(numero);
  }

  // Buscar patrimônios por sala
  List<Patrimonio> getPatrimoniosBySala(String sala) {
    return HiveDatabase.getPatrimoniosBySala(sala);
  }

  // Atualizar patrimônio (marcar como modificado)
  Future<void> updatePatrimonio(Patrimonio patrimonio, Map<String, dynamic> changes) async {
    try {
      // 1. Preservar ou Criar Original Values
      // Se já existe originalValues, MANTÉM (para não perder o estado inicial da sessão).
      // Se não existe, cria com os valores atuais (que são os originais neste momento).
      final originalValues = patrimonio.originalValues ?? {
        'sala': patrimonio.sala,
        'responsavel': patrimonio.responsavel,
        'situacao': patrimonio.situacao,
        'observacoes': patrimonio.observacoes,
        'descricao': patrimonio.descricao,
      };

      // 2. Calcular Modified Fields
      // Compara os novos valores (changes) com os originais (originalValues)
      // Se o valor novo for igual ao original, remove do map de modificados.
      final currentModifiedFields = Map<String, dynamic>.from(patrimonio.modifiedFields ?? {});
      
      changes.forEach((key, newValue) {
        final originalValue = originalValues[key];
        if (newValue != originalValue) {
          currentModifiedFields[key] = newValue;
        } else {
          currentModifiedFields.remove(key);
        }
      });

      // Se não houver mais campos modificados, o item não está mais modificado (reverteu ao original)
      final isModified = currentModifiedFields.isNotEmpty;

      // 3. Criar versão atualizada
      final updatedPatrimonio = patrimonio.copyWith(
        isModified: isModified,
        modifiedFields: isModified ? currentModifiedFields : null,
        originalValues: isModified ? originalValues : null,
        resetTracking: !isModified, // Se não está modificado, limpa o tracking
      );

      // Aplicar mudanças nos campos principais
      final finalPatrimonio = updatedPatrimonio.copyWith(
        sala: changes['sala'] ?? patrimonio.sala,
        responsavel: changes['responsavel'] ?? patrimonio.responsavel,
        situacao: changes['situacao'] ?? patrimonio.situacao,
        observacoes: changes['observacoes'] ?? patrimonio.observacoes,
        descricao: changes['descricao'] ?? patrimonio.descricao,
      );

      await HiveDatabase.updatePatrimonio(finalPatrimonio);

      // Atualizar lista local
      final index = _patrimonios.indexWhere((p) => p.numeroPatrimonio == patrimonio.numeroPatrimonio);
      if (index != -1) {
        _patrimonios[index] = finalPatrimonio;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erro ao atualizar patrimônio: $e';
      notifyListeners();
    }
  }

  // Adicionar novo patrimônio (localmente)
  Future<void> addPatrimonio(Patrimonio patrimonio) async {
    try {
      await HiveDatabase.savePatrimonioData([patrimonio]); // savePatrimonioData handles add/update
      _patrimonios.add(patrimonio);
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao adicionar patrimônio: $e';
      notifyListeners();
    }
  }

  // Enviar alterações para o backend
  Future<void> sendUpdatesToBackend() async {
    final modifiedPatrimonios = _patrimonios.where((p) => p.isModified).toList();

    if (modifiedPatrimonios.isEmpty) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final updates = modifiedPatrimonios.map((p) => {
        'numero_patrimonio': p.numeroPatrimonio,
        'sala': p.sala,
        'responsavel': p.responsavel,
        'situacao': p.situacao,
        'observacoes': p.observacoes,
      }).toList();

      final response = await http.post(
        Uri.parse('$baseUrl/patrimonio/update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        // Marcar como não modificados após envio bem-sucedido
        for (final patrimonio in modifiedPatrimonios) {
          final updated = patrimonio.copyWith(
            isModified: false,
            modifiedFields: null,
            originalValues: null,
            updatedAt: DateTime.now(),
          );
          await HiveDatabase.updatePatrimonio(updated);
        }

        // Recarregar dados
        await loadLocalData();
      } else {
        throw Exception('Erro ao enviar atualizações: ${response.statusCode}');
      }
    } catch (e) {
      _error = 'Erro ao enviar atualizações: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Limpar erro
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Obter estatísticas
  Map<String, int> getStatistics() {
    final modified = _patrimonios.where((p) => p.isModified).length;
    final total = _patrimonios.length;
    final synced = total - modified;

    return {
      'total': total,
      'modified': modified,
      'synced': synced,
    };
  }
}
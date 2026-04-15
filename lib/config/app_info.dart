// Classe auxiliar para obter e gerenciar informações globais do aplicativo.
//
// Fornece acesso a informações como versão, nome e data de lançamento do app.
// Estas informações são carregadas dinamicamente e podem ser acessadas de qualquer lugar do app.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  static String appName = 'Controle de Patrimônio';
  static String version = '0.0.0';
  static String buildNumber = '0';
  static String releaseDate = '';
  static bool _initialized = false;
  
  /// Inicializa as informações do app, carregando dados do sistema
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Usar package_info_plus para obter informações oficiais do pacote instalado
      final packageInfo = await PackageInfo.fromPlatform();
      
      // Atualizar as informações com os dados oficiais
      appName = packageInfo.appName.isEmpty ? 'Controle de Patrimônio' : packageInfo.appName;
      version = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
      
      debugPrint('AppInfo inicializado: $appName v$version+$buildNumber');
      
      // Configurar a data como a data atual
      // Usar formato simples para evitar dependência de locales do sistema
      final now = DateTime.now();
      final months = [
        'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
        'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
      ];
      releaseDate = '${now.day} de ${months[now.month - 1]} de ${now.year}';
      _initialized = true;
    } catch (e) {
      debugPrint('Erro ao carregar informações do app: $e');
      // Usar valor padrão em caso de erro - será atualizado dinamicamente
      releaseDate = 'data indisponível';
    }
  }
  
  /// Retorna a versão completa no formato "X.Y.Z (build N)"
  static String getFullVersion() {
    return '$version (build $buildNumber)';
  }
}

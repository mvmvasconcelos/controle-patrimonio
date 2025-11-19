import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class FeedbackUtils {
  /// Fornece feedback háptico (vibração)
  static Future<void> provideHapticFeedback() async {
    try {
      debugPrint('Tentando feedback háptico (abordagem 1)...');
      
      // Primeira abordagem: vibração mais forte e duradoura
      await HapticFeedback.heavyImpact();
      
      // Segunda abordagem: múltiplas vibrações em sequência
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.vibrate();
      
      // Terceira abordagem: vibração seletiva (mais compatível com certos dispositivos)
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.selectionClick();
      
      debugPrint('Feedback háptico concluído');
    } catch (e) {
      debugPrint('⚠️ Erro no feedback háptico: $e');
    }
  }
  
  /// Fornece feedback sonoro (beep)
  static Future<void> provideSoundFeedback() async {
    AudioPlayer? player;
    
    try {
      debugPrint('Iniciando feedback sonoro...');
      player = AudioPlayer();
      
      // Configurar volume antes de reproduzir
      await player.setVolume(0.5);
      
      // Tentar reproduzir o som com caminho explícito
      await player.play(AssetSource('sounds/beep.mp3'));
      debugPrint('Feedback sonoro iniciado');
      
      // Aguardar um curto período para garantir que o som seja reproduzido
      await Future.delayed(const Duration(milliseconds: 300));
      debugPrint('Feedback sonoro concluído');
    } catch (e) {
      debugPrint('⚠️ Erro no feedback sonoro: $e');
      
      // Tentar método alternativo se o primeiro falhar
      try {
        await player?.stop();
        await player?.dispose();
        
        // Criar um novo player e tentar novamente com uma abordagem diferente
        player = AudioPlayer();
        await player.setSourceAsset('sounds/beep.mp3');
        await player.resume();
        debugPrint('Feedback sonoro alternativo concluído');
      } catch (fallbackError) {
        debugPrint('⚠️ Erro no feedback sonoro alternativo: $fallbackError');
      }
    } finally {
      // Garantir que o player seja descartado se foi criado
      try {
        if (player != null) {
          await player.dispose();
          debugPrint('AudioPlayer descartado com sucesso');
        }
      } catch (e) {
        debugPrint('Erro ao descartar AudioPlayer: $e');
      }
    }
  }
}

// lib/shared/utils/json_file_export_util.dart
//用來儲存log
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// JSON 檔案輸出工具類
/// 用於將 API 回應數據導出到 JSON 檔案
class JsonFileExportUtil {

  /// 將數據輸出為 JSON 檔案
  /// [data] - 要輸出的數據（可以是 Map, List, 或任何可序列化的對象）
  /// [fileName] - 檔案名稱（不包含副檔名）
  /// [description] - 檔案描述（可選）
  static Future<String?> exportToJsonFile({
    required dynamic data,
    required String fileName,
    String? description,
  }) async {
    try {
      // 獲取應用程式文件目錄
      final directory = await getApplicationDocumentsDirectory();
      final jsonDir = Directory('${directory.path}/exported_json');

      // 確保目錄存在
      if (!await jsonDir.exists()) {
        await jsonDir.create(recursive: true);
      }

      // 生成帶時間戳的檔案名
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fullFileName = '${fileName}_$timestamp.json';
      final filePath = '${jsonDir.path}/$fullFileName';

      // 創建包含元數據的完整 JSON 結構
      final exportData = {
        'metadata': {
          'exportTime': DateTime.now().toIso8601String(),
          'fileName': fullFileName,
          'description': description ?? 'API response data export',
          'dataType': data.runtimeType.toString(),
          'dataSize': _calculateDataSize(data),
        },
        'rawData': data,
      };

      // 轉換為 JSON 字符串（格式化輸出）
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // 寫入檔案
      final file = File(filePath);
      await file.writeAsString(jsonString);

      // 輸出成功訊息
      print('✅ JSON 檔案已成功輸出!');
      print('📁 檔案路徑: $filePath');
      print('📊 檔案大小: ${(jsonString.length / 1024).toStringAsFixed(2)} KB');
      print('⏰ 輸出時間: ${DateTime.now()}');

      return filePath;

    } catch (e) {
      print('❌ 輸出 JSON 檔案時發生錯誤: $e');
      return null;
    }
  }

  /// 專門用於 Mesh Topology API 的導出
  static Future<String?> exportMeshTopologyData(dynamic meshData) async {
    return await exportToJsonFile(
      data: meshData,
      fileName: 'mesh_topology_raw_data',
      description: 'Raw data from /api/v1/system/mesh_topology endpoint',
    );
  }

  /// 批量導出多個 API 的數據
  static Future<List<String>> exportMultipleApiData(Map<String, dynamic> apiDataMap) async {
    final List<String> exportedFiles = [];

    for (final entry in apiDataMap.entries) {
      final filePath = await exportToJsonFile(
        data: entry.value,
        fileName: 'api_${entry.key}',
        description: 'API response data for ${entry.key}',
      );

      if (filePath != null) {
        exportedFiles.add(filePath);
      }
    }

    print('📦 批量導出完成，共 ${exportedFiles.length} 個檔案');
    return exportedFiles;
  }

  /// 計算數據大小（估算）
  static int _calculateDataSize(dynamic data) {
    try {
      final jsonString = json.encode(data);
      return jsonString.length;
    } catch (e) {
      return 0;
    }
  }

  /// 列出所有已導出的 JSON 檔案
  static Future<List<File>> listExportedFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final jsonDir = Directory('${directory.path}/exported_json');

      if (!await jsonDir.exists()) {
        return [];
      }

      final files = await jsonDir.list()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .cast<File>()
          .toList();

      return files;

    } catch (e) {
      print('❌ 列出導出檔案時發生錯誤: $e');
      return [];
    }
  }

  /// 清理舊的導出檔案（保留最近 N 個）
  static Future<void> cleanupOldFiles({int keepCount = 10}) async {
    try {
      final files = await listExportedFiles();

      if (files.length <= keepCount) {
        return;
      }

      // 按修改時間排序，保留最新的檔案
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      final filesToDelete = files.skip(keepCount).toList();

      for (final file in filesToDelete) {
        await file.delete();
        print('🗑️ 已刪除舊檔案: ${file.path}');
      }

      print('🧹 清理完成，保留最新 $keepCount 個檔案');

    } catch (e) {
      print('❌ 清理檔案時發生錯誤: $e');
    }
  }

  /// 獲取導出目錄路徑
  static Future<String> getExportDirectoryPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/exported_json';
  }
}
# UI 佈局風格指南 - Wi-Fi 5G IOT APP

本文檔定義了 Wi-Fi 5G IOT APP 的統一設計風格、間距、顏色和排版規則，所有UI開發應遵循此指南以確保視覺一致性。

## 顏色系統

### 主要顏色
- **主背景色**：`Colors.white` (#FFFFFF)
- **次要背景色**：`Color(0xFFEFEFEF)` (淺灰)
- **輸入區域背景**：`Color(0xFFFFFFFF)` (白色)
- **按鈕背景色**：`Color(0xFFDDDDDD)` (中灰)
- **陰影色**：不使用明顯陰影

### 文字顏色
- **主要文字色**：`Colors.black` (#000000)
- **次要文字色**：`Colors.grey` (灰色)
- **按鈕文字色**：`Colors.black` (#000000)

### 邊框顏色
- **主要邊框色**：`Colors.grey[400]` (中灰)
- **次要邊框色**：`Colors.grey[300]` (淺灰)

### 狀態顏色
- **活動/選中狀態**：`Colors.black` (黑色)
- **未活動/未選中**：`Colors.grey[200]` (淺灰)

## 間距系統

### 頁面佈局間距
- **頁面邊距**：20px
- **主要區域上邊距**：螢幕高度的5%
- **組件間垂直間距**：20px

### 元素內部間距
- **按鈕內邊距**：垂直16px，水平16px
- **輸入區域內邊距**：垂直16px，水平16px
- **卡片/容器內邊距**：25px

### 元素間間距
- **相關元素間間距(小)**：8px
- **相關元素間間距(中)**：16-20px
- **不同功能區間距(大)**：30px
- **按鈕之間的間距**：20px

## 排版系統

### 字體
- **全局字體**：系統默認字體
- **不使用自定義字體**

### 字體大小
- **大標題**：32px (例如頁面標題)
- **中標題**：22px (例如組件標題)
- **小標題**：18px (例如輸入區標籤)
- **正文文字**：16px
- **小型文字**：13-15px (例如次要資訊)
- **微型文字**：10px (例如MAC地址顯示)

### 字體粗細
- **加粗標題**：`FontWeight.bold`
- **常規文字**：`FontWeight.normal`

## 組件設計規範

### 按鈕設計
- **高度**：50-56px
- **寬度**：根據需求(固定寬度或自適應)
- **背景**：`Color(0xFFDDDDDD)` (中灰)
- **文字顏色**：`Colors.black`
- **邊框**：`Colors.grey[400]`
- **圓角**：無 (0px，方角設計)
- **禁用狀態**：降低不透明度或使用淺灰色

### 輸入框設計
- **高度**：56px
- **背景**：`Colors.white`
- **文字顏色**：`Colors.black`
- **邊框**：無邊框或極淺邊框
- **填充顏色**：`Colors.white`
- **標籤位置**：輸入框上方
- **標籤樣式**：18px，常規粗細

### 容器/卡片設計
- **背景色**：`Color(0xFFEFEFEF)` (淺灰)
- **邊框**：通常無邊框
- **內邊距**：25px
- **高度**：通常為內容自適應或佔螢幕比例

### 步驟導航(StepperComponent)
- **圓圈直徑**：60px
- **圓圈邊框**：1-2px
- **當前步驟**：白色背景，黑色邊框，黑色文字
- **完成步驟**：黑色背景，白色勾號
- **未完成步驟**：淺灰背景，灰色文字
- **連接線高度**：4px
- **連接線顏色**：已完成部分為黑色，未完成部分為淺灰

### 設備方塊(如WifiScannerComponent中)
- **背景色**：`Color(0xFFDDDDDD)` (中灰)
- **尺寸**：80px x 80px (默認)
- **間距**：20px
- **邊框**：`Colors.grey[300]`

## 佈局規則

### 頁面結構
- **頂部**：通常是步驟導航或標題(佔比約10-15%)
- **中部**：主要內容區域(佔比約70-80%)
- **底部**：導航按鈕區域(佔比約10-15%)

### 表單設計
- **標籤位置**：表單項上方
- **垂直佈局**：標籤、輸入框垂直排列
- **表單驗證**：錯誤信息通過SnackBar提示，不在輸入框下方顯示

### 響應式設計
- **使用MediaQuery**：獲取螢幕尺寸進行相對佈局
- **關鍵尺寸**：使用螢幕比例計算，不使用固定像素值
- **內容適應**：使用FittedBox確保內容在小螢幕上可以適當縮小

## 設計變體

### 型號A樣式
- 遵循主要設計語言
- 具有完整的設置流程

### 型號B樣式
- 相同的設計語言
- 簡化的設置流程
- 具有型號特定的頁面

## 代碼實現指導

### 顏色常量
```dart
// 在一個統一的主題文件中定義
const Color mainBackgroundColor = Colors.white;
const Color secondaryBackgroundColor = Color(0xFFEFEFEF);
const Color inputBackgroundColor = Colors.white;
const Color buttonBackgroundColor = Color(0xFFDDDDDD);
const Color buttonBorderColor = Color(0xFFD0D0D0);
```

### 文字樣式常量
```dart
// 在一個統一的主題文件中定義
const TextStyle titleStyle = TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.bold,
  color: Colors.black,
);

const TextStyle subtitleStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.bold,
  color: Colors.black,
);

const TextStyle labelStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.normal,
  color: Colors.black,
);

const TextStyle bodyStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.normal,
  color: Colors.black,
);
```

### 間距常量
```dart
// 在一個統一的主題文件中定義
const double pagePadding = 20.0;
const double componentSpacing = 20.0;
const double elementSpacingSmall = 8.0;
const double elementSpacingMedium = 16.0;
const double elementSpacingLarge = 30.0;
```

### 組件樣式示例
```dart
// 按鈕樣式
ElevatedButton(
  onPressed: onPressed,
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFFDDDDDD),
    foregroundColor: Colors.black,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(0),
      side: BorderSide(color: Colors.grey[400]!),
    ),
  ),
  child: Text('Button Text'),
)

// 輸入框樣式
TextFormField(
  decoration: InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: BorderSide.none,
    ),
    labelText: 'Label Text',
  ),
)
```

## 使用注意事項

1. **一致性原則**：所有UI元素必須遵循本指南
2. **變更流程**：UI樣式的變更必須更新本文檔
3. **優先使用常量**：避免在代碼中硬編碼樣式值
4. **組件優先**：優先使用現有組件，避免重複實現類似功能
5. **跨設備測試**：確保在不同尺寸的設備上進行測試

## 附錄：樣式檢查清單

在提交代碼前，請檢查：
- [ ] 所有顏色是否使用指定顏色
- [ ] 間距是否符合規範
- [ ] 文字樣式是否一致
- [ ] 組件樣式是否符合設計
- [ ] 響應式佈局是否正確實現
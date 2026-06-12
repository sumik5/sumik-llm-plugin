---
description: XMLセキュリティと安全なデシリアライゼーション（DTD/XXEの堅牢化、スキーマ検証、安全でないネイティブデシリアライゼーションの禁止）
languages:
- c
- go
- java
- php
- python
- ruby
- xml
alwaysApply: false
---

rule_id: codeguard-0-xml-and-serialization

## XML・シリアライゼーションの堅牢化

XMLおよびシリアライズされたデータの安全なパースと処理。XXE、エンティティ展開、SSRF、DoS、および安全でないデシリアライゼーションをプラットフォーム横断で防止する。

### XMLパーサーの堅牢化
- デフォルトでDTDと外部エンティティを無効化し、DOCTYPE宣言を拒否する。
- ローカルの信頼できるXSDに対して厳格に検証し、明示的な制限（サイズ、深さ、要素数）を設定する。
- リゾルバーのアクセスをサンドボックス化またはブロックし、パース中のネットワーク通信を行わず、予期しないDNSアクティビティを監視する。

#### Java
基本原則：
```java
factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
```

DTDを無効化することでXXEおよびBillion Laughs攻撃から保護される。DTDを無効化できない場合は、パーサー固有の方法で外部エンティティを無効化する。

### Java

JavaのパーサーはデフォルトでXXEが有効になっている。

DocumentBuilderFactory/SAXParserFactory/DOM4J：

```java
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
String FEATURE = null;
try {
    // PRIMARY defense - disallow DTDs completely
    FEATURE = "http://apache.org/xml/features/disallow-doctype-decl";
    dbf.setFeature(FEATURE, true);
    dbf.setXIncludeAware(false);
} catch (ParserConfigurationException e) {
    logger.info("ParserConfigurationException was thrown. The feature '" + FEATURE
    + "' is not supported by your XML processor.");
}
```

DTDを完全に無効化できない場合：

```java
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
String[] featuresToDisable = {
    "http://xml.org/sax/features/external-general-entities",
    "http://xml.org/sax/features/external-parameter-entities",
    "http://apache.org/xml/features/nonvalidating/load-external-dtd"
};

for (String feature : featuresToDisable) {
    try {    
        dbf.setFeature(feature, false); 
    } catch (ParserConfigurationException e) {
        logger.info("ParserConfigurationException was thrown. The feature '" + feature
        + "' is probably not supported by your XML processor.");
    }
}
dbf.setXIncludeAware(false);
dbf.setExpandEntityReferences(false);
dbf.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
```

#### .NET
```csharp
var settings = new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null };
var reader = XmlReader.Create(stream, settings);
```

#### Python
```python
from defusedxml import ElementTree as ET
ET.parse('file.xml')
# or lxml
from lxml import etree
parser = etree.XMLParser(resolve_entities=False, no_network=True)
tree = etree.parse('filename.xml', parser)
```

### 安全なXSLT/Transformerの使用
- `ACCESS_EXTERNAL_DTD` と `ACCESS_EXTERNAL_STYLESHEET` を空に設定し、リモートリソースの読み込みを避ける。

### デシリアライゼーションの安全性
- 信頼できないネイティブオブジェクトは絶対にデシリアライズしてはならない。スキーマ検証を伴うJSONを優先する。
- パース前にサイズ・構造の制限を適用する。厳密に許可リスト化されていない限り、ポリモーフィック型を拒否する。
- 言語固有の注意事項：
  - PHP：`unserialize()` を避け、`json_decode()` を使用する。
  - Python：`pickle` および安全でないYAML（`yaml.safe_load` のみ使用）を避ける。
  - Java：`ObjectInputStream#resolveClass` をオーバーライドして許可リスト化する。Jacksonでのデフォルト型指定の有効化を避ける。XStreamの許可リストを使用する。
  - .NET：`BinaryFormatter` を避け、`DataContractSerializer` または JSON.NET では `TypeNameHandling=None` を指定した `System.Text.Json` を優先する。
- 該当する場合はシリアライズされたペイロードに署名して検証する。デシリアライゼーションの失敗や異常をログに記録してアラートを発する。

### 実装チェックリスト
- DTDをオフにする。外部エンティティを無効化する。厳格なスキーマ検証を行う。パーサーの制限を設定する。
- パース中のネットワークアクセスを禁止する。リゾルバーを制限する。監査を実施する。
- 安全でないネイティブデシリアライゼーションを行わない。サポートされるフォーマットに対して厳格な許可リストとスキーマ検証を適用する。
- ライブラリを定期的に更新し、XXE/デシリアライゼーションペイロードでテストする。

# サニタイズ回帰テスト用fixture

このファイルは `md-to-html.sh` のサニタイズ回帰テスト専用の悪性サンプルである。
実運用のドキュメントには使用しない。

## 1. script タグ

<script>alert(1)</script>

## 2. onerror属性を持つimgタグ（生HTML）

<img src=x onerror="alert(1)">

## 3. javascript: スキームのリンク

[クリックしないで](javascript:alert(1))

## 4. 外部オリジンへのimg参照

![外部画像](http://evil.example.com/track.png)

## 5. iframeタグ

<iframe src="http://evil.example.com"></iframe>

# R データ分析

## データ読み込み

- CSV/TSV は `readr::read_csv()`、大容量では `vroom` や `data.table::fread()` を検討する。
- Excel は `readxl`、JSON は `jsonlite`、DB は `DBI` と driver、遅延 SQL 変換は `dbplyr` を使う。
- 型推定に任せきらない。列型、ロケール、文字コード、欠損表現、日付形式を明示する。
- 中間データは `saveRDS()`/`readRDS()` が安全。`.RData` に複数 object を詰め込む運用は再現性を落としやすい。
- ファイルパスは `here`、`rprojroot`、設定値、関数引数で扱う。`setwd()` 前提のスクリプトにしない。

## 整形と変換

- dplyr の基本順序は `filter()`、`select()`、`mutate()`、`group_by()`、`summarise()`、`arrange()`。
- join はキーの一意性と行数の増減を確認する。many-to-many join は明示的に意図を書く。
- wide/long 変換は `tidyr::pivot_longer()` と `pivot_wider()` を使う。列名に複数情報を詰めたデータは先に分解する。
- 文字列は `stringr`、日付時刻は `lubridate`、カテゴリ順序は `forcats` を使うと意図が読みやすい。
- `rowwise()` は便利だが遅くなりやすい。ベクトル化、list-column、nest/map、join で置き換えられないか確認する。

## EDA

- 最初に行数、列数、型、欠損数、重複、範囲、カテゴリ水準、サンプルを確認する。
- `summary()`、`str()`、`glimpse()`、`skimr::skim()` を使い、異常値と欠損パターンを分けて見る。
- 分布は histogram、density、boxplot、violin、カテゴリは bar、関係性は scatter、line、heatmap を使い分ける。
- サンプルサイズ、欠損除外数、外れ値処理、単位変換を分析結果の近くに残す。

## ggplot2

- ggplot2 は data、aesthetic mapping、geom、stat、scale、coord、facet、theme の層で考える。
- 軸ラベル、単位、凡例、色の意味、facet のスケールを明示する。
- 連続値にカテゴリ palette、カテゴリに連続 scale を当てない。
- y 軸を省略・切断するときは誤解を生まない表示にする。
- 画像保存は `ggsave()` で width、height、dpi、device を指定する。レポートや論文用は表示先の比率に合わせる。

## 統計解析

- 検定前に仮説、母集団、サンプル抽出、対応の有無、独立性、尺度、分布仮定を確認する。
- p 値だけで結論を書かない。推定値、信頼区間、効果量、サンプルサイズ、仮定の限界を併記する。
- 回帰では目的変数、説明変数、交互作用、非線形性、多重共線性、残差、外れ値、影響点を確認する。
- 多重検定、データ探索後の仮説設定、欠損除外、外れ値除外は結論を強く左右する。
- 予測目的と説明目的を混同しない。説明目的ならモデルの解釈可能性と仮定、予測目的なら汎化性能を優先する。

## レポート化

- 分析本文、コード、図表、session 情報、入力ファイルの由来を同じ成果物から再生成できるようにする。
- R Markdown/Quarto では chunk option を明示する。`echo`、`warning`、`message`、`cache`、`fig.width`、`fig.height` を成果物に合わせる。
- キャッシュは依存関係が変わったときに無効化できる設計にする。古い中間結果を読み続けない。


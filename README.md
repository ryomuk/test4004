# test4004
Test system for Intel MCS-4 (4004)  micro computer set

This document is written mostly in Japanese.
If necessary, please use a translation service such as DeepL (I recommend this) or Google.

![](images/title.jpg)
![](images/breadboard.jpg)

## 概要
昨年，運良くIntel 4004を入手することができました．せっかくだから動かしてみようと思い，このプロジェクトを始めました．現在進行中の未完成プロジェクトです．

## これまでに作ったもの
- 4004実験用ボード
  - シリアル通信用インターフェース
  - 簡易モニター
  - 電卓

## ToDO
- VTL的な言語
  - マンデルブロ集合を表示するぐらいのプログラムを実行させたい
- プログラムメモリのRAM領域の拡大
  - 現在の実装では256byteに制限されている
→ バンク切り替えで256byte x 8面使えるようにした．(2023/2/20)
- プリント基板作成

## 動画
Youtubeで関連動画を公開しています．
- https://www.youtube.com/@ryomukai/videos

## ブログ
関連する情報が書いてあるかも．
- https://blog.goo.ne.jp/tk-80

## 参考にした文献，サイト
### 4004関連開発事例
- [Intel 4004  50th Anniversary Project](https://www.4004.com/)
  - https://www.4004.com/busicom-replica.html
  - http://www.4004.com/2009/Busicom-141PF-Calculator_asm_rel-1-0-1.txt
- https://github.com/jim11662418/4004-SBC
- https://www.cpushack.com/mcs-4-test-boards-for-sale
- https://github.com/novi/4004MainBoard


### データシート
- http://www.bitsavers.org/components/intel/
- https://www.intel-vintage.info/intelmcs.htm

### 開発環境
- [The Macroassembler AS](http://john.ccac.rwth-aachen.de:8000/as/)
- [Intel 4004 emulator assembler disassembler](http://e4004.szyc.org/)


## 更新履歴
- 2023/2/20: ハードウェアをrev.0.2に更新
  - プログラム領域のメモリ(6116)のA8〜A10を4002のポートに接続してバンク切り替えで256byte(正確には254byte) x 8 バンク使えるようにしました．
  - モニターの'B'命令で切り替えます．
  -  バンク窓以外の空間をROM領域に使うように改修する余地ができたので，将来必要になれば改修したい．

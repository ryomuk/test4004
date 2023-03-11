# test4004
Test system for Intel MCS-4 (4004)  micro computer set

This document is written mostly in Japanese.
If necessary, please use a translation service such as DeepL (I recommend this) or Google.

![](images/title.jpg)
![](images/breadboard.jpg)

## 概要
昨年，運良くIntel 4004を入手することができました．せっかくだから動かしてみようと思い，このプロジェクトを始めました．
このレポジトリ(test4004)は電卓を作ったところまでで完成．続きはメモリ関連のハードウェアの変更も伴うので別レポジトリ(https://github.com/ryomuk/VTL4004)に移行します．

## これまでに作ったもの
- 4004実験用ボード
  - シリアル通信用インターフェース
  - 簡易モニター
  - 電卓
  - [VTLインタプリタ(VTL4004)](https://github.com/ryomuk/VTL4004)

## 実験用ボードの仕様
- CPU: Intel 4004
- Clock: 740kHz
- DATA RAM: 4002-1(320bit) x 4
- Program Memory
  - ROM: AT28C64B (8k x 8bit EEPROM)
    - 000H〜EFFHの3.75KB利用可能
  - RAM: HM6268(4k x 4bit SRAM)x 2個
    - F00H〜FFDHの254byte x 16バンク, 合計約4KB
- 通信ポート: 9600bps Software Serial UART (TTL level)

## ToDO
- VTL的な言語
  - マンデルブロ集合を表示するぐらいのプログラムを実行させたい
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
  - プログラム領域のメモリ(6116)のA8〜A10を4002のポートに接続してバンク切り替えで256byte(正確には254byte) x 8 バンク使えるようにした．
  -  これに伴い，バンク窓以外の空間をROM用に使う余地がある．
  - モニタプログラムにバンク切り替え命令('B')を追加．
  - rev.0.1は，「CM0とCM1に4002-1を2づつ」という構成でしたが，「CM0に4002-1を2つと4002-2を2つ」という構成も可能にしました．ピンヘッダでCMのラインを切り替えます．
- 2023/2/21: PM_READ_P0_P2 を PM_READ_P0_P1 に変更．
- 2023/2/23: 上記にバグがあったので修正．CTOI_P1_R5をCTOI_P1に変更．
- 2023/2/24: ハードウェアをrev.1.0に更新
  - プログラム領域のROMを2716から28C64B(2764等も可)に変更．
    - 000H〜7FFHだったROM領域を000H〜EFFHに拡大
  - プログラム領域のRAMを6116から6268(たぶん6168でも可)に変更
    - 254byte x 16 バンク使えるようにした．
  - 通信ポートをRAM3に，PMのRAMバンク指定用のポートをRAM0に変更

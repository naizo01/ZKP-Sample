# ZK-SNARKs実践入門 - Circomとsnarkjsによるゼロ知識証明の実装

## はじめに

ZK-SNARK を実際のプロジェクトで活用するための基礎的な実装方法を解説します。具体的には、環境のセットアップから簡単な回路の作成、そして Solidity 検証コントラクトの生成までの一連の流れを説明します。

ゼロ知識証明、特に zk-SNARK は暗号技術分野で最も注目される技術の 1 つです。その理由として：

1. 情報を公開せずにその保有を証明可能（例：匿名投票）
2. 証明が小さく、ブロックチェーン上での検証が容易（例：ロールアップ）

## 環境セットアップ

### 1. Circom のインストール

まず、Rust 環境をインストール：

```bash
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
```

Circom のインストール：

```bash
git clone https://github.com/iden3/circom.git
cd circom
cargo build --release
cargo install --path circom
cd ..
```

### 2. プロジェクトの準備

新しいプロジェクトディレクトリを作成し、必要なパッケージをインストール：

```bash
npm init -y
# circomlibは、ZK回路開発に必要な基本的なコンポーネント（ハッシュ関数、暗号演算など）を提供するライブラリです
npm i circomlib
```

## 基本的な回路の作成

`hash_poseidon.circom`を作成します：

```circom
pragma circom 2.0.0;
include "node_modules/circomlib/circuits/poseidon.circom";

// 入力値のPoseidonハッシュを計算する回路
template HashPoseidon() {
    // 入力値
    signal input in;
    // 計算されたハッシュ値
    signal output out;

    // Poseidonハッシュコンポーネント（入力1つ）
    component poseidon = Poseidon(1);
    poseidon.inputs[0] <== in;
    out <== poseidon.out;
}

// メインコンポーネントとして回路を定義
component main = HashPoseidon();
```

この回路は入力値に対して Poseidon ハッシュを計算します。

1. **入力（input）**:

   - 単一の数値を受け取ります（`in`）
   - JavaScript から `{ in: 数値 }` の形式で値を渡します

2. **処理**:

   - 入力値に対して Poseidon ハッシュを計算
   - Poseidon は、ZK 証明に適した効率的なハッシュ関数

3. **出力（output）**:
   - ハッシュ値（`out`）として有限体上の数値を返します

### 回路のコンパイル

```bash
mkdir build
circom hash_poseidon.circom --wasm --r1cs -o ./build
```

### 証明キーの生成

1. ptau ファイルのダウンロード：

```bash
wget https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_12.ptau
```

- ptau ファイルは信頼設定のためのファイルで、テスト用に snarkjs リポジトリ(https://github.com/iden3/snarkjs)で公開されているものを使用します
- 本番環境では「トラステッドセットアップ」と呼ばれる準備が必要です。

2. 証明キー（zkey）の生成：

```bash
mkdir -p build/zkey
npx snarkjs groth16 setup build/hash_poseidon.r1cs powersOfTau28_hez_final_12.ptau build/zkey/hash_poseidon.zkey
```

- zkey は回路特有の証明キーで、ptau ファイルと回路から生成されます。
- このファイルは証明の生成に使用されます。

## 証明の生成と検証

必要なパッケージをインストール：

```bash
npm i snarkjs
mkdir -p build/json
```

### 証明の生成

`hash_generate_proof.js`を作成：

```javascript
const snarkjs = require("snarkjs");
const fs = require("fs");

async function main() {
  // 入力値10に対する証明を生成
  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    { in: 10 },
    "build/hash_poseidon_js/hash_poseidon.wasm",
    "build/zkey/hash_poseidon.zkey"
  );

  fs.writeFileSync("build/json/hash_proof.json", JSON.stringify(proof));
  fs.writeFileSync(
    "build/json/hash_public.json",
    JSON.stringify(publicSignals)
  );

  console.log("Generated Proof:", proof);
  console.log("Public Signals:", publicSignals);

  // Solidity用のコールデータを生成
  const calldata = await snarkjs.groth16.exportSolidityCallData(
    proof,
    publicSignals
  );
  console.log("Solidity Calldata:", calldata);
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
```

- `exportSolidityCallData`関数は、ZK 証明を Solidity コントラクトで検証するために必要なデータを適切な形式に変換します

proof 生成を実行：

```bash
node hash_generate_proof.js
```

### 検証キーの生成と検証用 Solidity コードの生成

検証キーの生成：

```bash
npx snarkjs zkey export verificationkey build/zkey/hash_poseidon.zkey build/json/hash_verification_key.json
```

Solidity 検証コントラクトの生成：

```bash
npx snarkjs zkey export solidityverifier build/zkey/hash_poseidon.zkey src/HashPoseidonVerifier.sol
```

### 証明の検証

`hash_verify_proof.js`を作成：

```javascript
const snarkjs = require("snarkjs");
const fs = require("fs");

async function main() {
  const vKey = JSON.parse(
    fs.readFileSync("build/json/hash_verification_key.json")
  );
  const proof = JSON.parse(fs.readFileSync("build/json/hash_proof.json"));
  const publicSignals = JSON.parse(
    fs.readFileSync("build/json/hash_public.json")
  );

  const res = await snarkjs.groth16.verify(vKey, publicSignals, proof);

  if (res === true) {
    console.log("検証成功");
  } else {
    console.log("無効な証明");
  }
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
```

検証を実行：

```bash
node hash_verify_proof.js
```

### Solidity の verify テスト

1. **テストファイルの作成**:
   `test/HashPoseidonVerifier.test.sol` ファイルを作成し、以下の内容を追加します。

   ```solidity
   // SPDX-License-Identifier: UNLICENSED
   pragma solidity ^0.8.13;

   import {Test, console2} from "forge-std/Test.sol";
   import "../src/HashPoseidonVerifier.sol";

   contract HashPoseidonVerifierTest is Test {
       Groth16Verifier public verifier;

       struct ZKProof {
           uint[2] pA;
           uint[2][2] pB;
           uint[2] pC;
           uint[1] pubSignals;
       }

       function setUp() public {
           verifier = new Groth16Verifier();
       }

       function testVerification() public view {
           ZKProof memory proof = ZKProof({
               pA: [
                   0x2b6a4316f2f1f092d40a4b2d5cefbcea4481c9c44fb5d08fceec1b9305b7a1f1,
                   0x2007796e2537d308eb519a3b4cacc76458a6144b9fd26136c9527fd652b8e72d
               ],
               pB: [
                   [
                       0x22b7aa4e410fcd1a03cfb82e68f6755f6b096e66dc6bd0d03b56e58ec7ec7efc,
                       0x053bbb51926cdfc719bb8b6af0ad53283514d5b548b39e0c2581156f798cf21f
                   ],
                   [
                       0x1ea282e747e04885c2bec21a9735bd5b1c2cd63d54e2062eecf29b7a44fb7d99,
                       0x225dfb89c4c0ca2da194115fa549bf4099cbe0222083140d0ce8551cbc414cad
                   ]
               ],
               pC: [
                   0x0b9fc717b2da15f97573fcc4b6b825299b247ee2e2c48bd3682ce43df6925490,
                   0x064650aca6cf17587a6ccdff5e9129bd511079d016af25b920d7fde2e355c172
               ],
               pubSignals: [
                   0x2778f900758cc46e051040641348de3dacc6d2a31e2963f22cbbfb8f65464241
               ]
           });

           bool result = verifier.verifyProof(
               proof.pA,
               proof.pB,
               proof.pC,
               proof.pubSignals
           );
           assertTrue(result, "Proof verification failed");
       }
   }
   ```

- ZKProof には、`exportSolidityCallData`関数で生成されたものを記述します。
- proof の内容は毎回変わります。

2. **テストを実行**:
   Foundry でテストを実行します。

   ```bash
   forge test
   ```

## パスワード認証のための回路

パスワードの認証を行う`password_check.circom`を作成します：

```circom
pragma circom 2.0.0;

include "node_modules/circomlib/circuits/poseidon.circom";

template PasswordCheck() {
    signal input in;      // プライベート入力（パスワード）
    signal input hash;    // パブリック入力（ハッシュ値）

    component poseidon = Poseidon(1);
    poseidon.inputs[0] <== in;
    hash === poseidon.out;  // ハッシュ値の一致を検証
}

// hashをパブリック入力として指定
component main {public [hash]} = PasswordCheck();
```

この回路の特徴：

1. **入力**:

   - `in`: プライベート入力（パスワード）
   - `hash`: パブリック入力（ハッシュ値）

2. **検証**:
   - パスワードのハッシュが登録済みハッシュと一致するか確認

### 認証用回路のコンパイルと証明生成

回路のコンパイル：

```bash
circom password_check.circom --wasm --r1cs -o ./build
```

証明キーの生成：

```bash
npx snarkjs groth16 setup build/password_check.r1cs powersOfTau28_hez_final_12.ptau build/zkey/password_check.zkey
```

circomlibjs をインストール：

```bash
npm i circomlibjs
```

`password_generate_proof.js`を作成：

```javascript
const snarkjs = require("snarkjs");
const circomlibjs = require("circomlibjs");
const fs = require("fs");

async function main() {
  const input = 123456789;
  const poseidon = await circomlibjs.buildPoseidon();
  const hash = poseidon.F.toString(poseidon([input]));

  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    { in: input, hash: hash },
    "build/password_check_js/password_check.wasm",
    "build/zkey/password_check.zkey"
  );

  fs.writeFileSync("build/json/password_proof.json", JSON.stringify(proof));
  fs.writeFileSync(
    "build/json/password_public.json",
    JSON.stringify(publicSignals)
  );

  console.log("Generated Proof:", proof);
  console.log("Public Signals:", publicSignals);

  // Solidity用のコールデータを生成
  const calldata = await snarkjs.groth16.exportSolidityCallData(
    proof,
    publicSignals
  );
  console.log("Solidity Calldata:", calldata);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
```

proof 生成を実行：

```bash
node password_generate_proof.js
```

検証キーの生成：

```bash
npx snarkjs zkey export verificationkey build/zkey/password_check.zkey build/json/password_verification_key.json
```

Solidity 検証コントラクトの生成：

```bash
npx snarkjs zkey export solidityverifier build/zkey/password_check.zkey src/PasswordCheckVerifier.sol
```

`password_verify_proof.js`を作成：

```javascript
const snarkjs = require("snarkjs");
const fs = require("fs");

async function main() {
  const vKey = JSON.parse(
    fs.readFileSync("build/json/password_verification_key.json")
  );
  const proof = JSON.parse(fs.readFileSync("build/json/password_proof.json"));
  const publicSignals = JSON.parse(
    fs.readFileSync("build/json/password_public.json")
  );

  const res = await snarkjs.groth16.verify(vKey, publicSignals, proof);

  if (res === true) {
    console.log("検証成功");
  } else {
    console.log("無効な証明");
  }
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
```

検証を実行：

```bash
node password_verify_proof.js
```

### 実践的な利用方法

この回路の活用例：

1. **パスワード認証**:

   - パスワードのハッシュを保存し、ログイン時に ZK 証明で認証

2. **アクセス制御**:

   - パスワードで操作権限を証明し、開示せずに認証

3. **秘密共有**:
   - パスワードを共有せずに、同じパスワードを持つことを証明

## まとめ

- circomlibjs と snarkjs は Node.js とブラウザの両方で動作
- クライアントサイドでの証明生成・検証が可能
- 生成された Solidity コードを使用してオンチェーンで検証可能

以下リポジトリに今回解説したソースコードをまとめてあります。
https://github.com/naizo01/ZKP-Sample

## 最後に

本記事では、東京大学ブロックチェーン講座で最優秀賞を受賞した、ZK 証明を活用したトラストレス相続アプリケーション「four next」の開発で実装した ZKP のセットアップ手順をまとめました。

- [デモアプリケーション](https://trustless-inheritance.vercel.app/)
- [資料](https://trustless-inheritance.vercel.app/presentation/)
- [Github](https://github.com/naizo01/TrustlessInheritance)

[@naizo_eth](https://x.com/naizo_eth)

#JavaScript での zk-SNARK・Circom・snark.js 入門

## はじめに

ZK-SNARK を実際のプロジェクトで活用するための基礎的な実装方法を解説します。具体的には、環境のセットアップから簡単な回路の作成、そして Solidity 検証コントラクトの生成までの一連の流れを説明します。

ゼロ知識証明、特に zk-SNARK は暗号技術分野で最も注目される技術の 1 つです。その理由として：

1. 情報を公開せずにその保有を証明可能（例：匿名投票への応用）
2. 証明が小さく、ブロックチェーン上での検証が容易（ロールアップに最適）

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

`poseidon_hash.circom`を作成します：

```circom
pragma circom 2.0.0;
include "node_modules/circomlib/circuits/poseidon.circom";

// 入力値のPoseidonハッシュを計算する回路
template PoseidonHash() {
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
component main = PoseidonHash();
```

この回路は入力値に対して Poseidon ハッシュを計算します。

1. **入力（input）**:
   - 単一の数値を受け取ります（`in`）
   - JavaScriptから `{ in: 数値 }` の形式で値を渡します

2. **処理**:
   - 入力値に対してPoseidonハッシュを計算
   - Poseidonは、ZK証明に適した効率的なハッシュ関数

3. **出力（output）**:
   - ハッシュ値（`out`）として有限体上の数値を返します

### 回路のコンパイル

```bash
mkdir build
circom poseidon_hash.circom --wasm --r1cs -o ./build
```

### 証明キーの生成

1. ptau ファイルのダウンロード：

```bash
wget https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_12.ptau
```
- ptauファイルは信頼設定のためのファイルで、テスト用にsnarkjsリポジトリ(https://github.com/iden3/snarkjs)で公開されているものを使用します
- 本番環境では「トラステッドセットアップ」と呼ばれる準備が必要です。

2. 証明キー（zkey）の生成：

```bash
mkdir -p build/zkey
npx snarkjs groth16 setup build/poseidon_hash.r1cs powersOfTau28_hez_final_12.ptau build/zkey/poseidon_hash.zkey
```
- zkeyは回路特有の証明キーで、ptauファイルと回路から生成されます。
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
    "build/poseidon_hash_js/poseidon_hash.wasm",
    "circuit_0000.zkey"
  );

  // JSONファイルを build/json ディレクトリに保存
  fs.writeFileSync("build/json/hash_proof.json", JSON.stringify(proof));
  fs.writeFileSync("build/json/hash_public.json", JSON.stringify(publicSignals));

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
npx snarkjs zkey export verificationkey build/zkey/poseidon_hash.zkey build/json/hash_verification_key.json
```

Solidity検証コントラクトの生成：
```bash
npx snarkjs zkey export solidityverifier build/zkey/poseidon_hash.zkey src/PoseidonHashVerifier.sol
```

### 証明の検証

`hash_verify_proof.js`を作成：

```javascript
const snarkjs = require("snarkjs");
const fs = require("fs");

async function main() {
  const vKey = JSON.parse(fs.readFileSync("build/json/hash_verification_key.json"));
  const proof = JSON.parse(fs.readFileSync("build/json/hash_proof.json"));
  const publicSignals = JSON.parse(fs.readFileSync("build/json/hash_public.json"));

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

## まとめ

- circomlibjs と snarkjs は Node.js とブラウザの両方で動作
- クライアントサイドでの証明生成・検証が可能
- 生成された Solidity コードを使用してオンチェーンで検証可能

## 最後に
本記事では、東京大学ブロックチェーン講座で最優秀賞を受賞した、ZK 証明を活用したトラストレス相続アプリケーション「four next」の開発で実装したZKPのセットアップ手順をまとめました。

- [デモアプリケーション](https://trustless-inheritance.vercel.app/)
- [資料](https://trustless-inheritance.vercel.app/presentation/)
- [Github](https://github.com/naizo01/TrustlessInheritance)

[@naizo_eth](https://x.com/naizo_eth)
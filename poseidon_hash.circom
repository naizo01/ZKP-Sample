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

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
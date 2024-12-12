const snarkjs = require("snarkjs");
const fs = require("fs");

async function main() {
    // 入力値10に対する証明を生成
    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
        { in: 10 }, 
        "build/poseidon_hash_js/poseidon_hash.wasm", 
        "build/zkey/poseidon_hash.zkey"
    );

    fs.writeFileSync("build/json/hash_proof.json", JSON.stringify(proof));
    fs.writeFileSync("build/json/hash_public.json", JSON.stringify(publicSignals));

    console.log("Generated Proof:", proof);
    console.log("Public Signals:", publicSignals);

    // Solidity用のコールデータを生成
    const calldata = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
    console.log("Solidity Calldata:", calldata);
}

main().then(() => {
    process.exit(0);
}).catch(err => {
    console.error(err);
    process.exit(1);
});
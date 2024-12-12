const snarkjs = require("snarkjs");
const circomlibjs = require("circomlibjs");
const fs = require("fs");

async function main() {
  const input = 123456789;
  const poseidon = await circomlibjs.buildPoseidon();
  const hash = poseidon.F.toString(poseidon([input]));

  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    { in: input, hash: hash  },
    "build/password_check_js/password_check.wasm",
    "build/zkey/password_check.zkey"
  );

  fs.writeFileSync("build/json/password_proof.json", JSON.stringify(proof));
  fs.writeFileSync("build/json/password_public.json", JSON.stringify(publicSignals));

  console.log("Generated Proof:", proof);
  console.log("Public Signals:", publicSignals);

    // Solidity用のコールデータを生成
    const calldata = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
    console.log("Solidity Calldata:", calldata);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
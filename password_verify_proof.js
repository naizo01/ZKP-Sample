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
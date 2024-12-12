// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../src/PasswordCheckVerifier.sol";

contract PasswordCheckVerifierTest is Test {
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
                0x06169d4f80edbe77f0627739f72ae56641dd957deeaf7e3315333023298e4b85,
                0x17a2cfbac34f7cf69fb75d680d47d3f630ca997b3bae411202b720a30dffc030
            ],
            pB: [
                [
                    0x1b6642f00089049f440de095835220719192aaf730614db5ca89cf8bf6d15d9a,
                    0x262bb3d103a4f4db94096aed3c331ff67e4298e86d6fa03d8c8f85a0042b184e
                ],
                [
                    0x2b77b52664f89d049b50a7e471af81e511c4dd3b3f4dcd34018f999265238aa9,
                    0x24062630897d70524c5175552b8666cea2a23d926c0fecc3eb250bd627bc8b30
                ]
            ],
            pC: [
                0x16668c3357f1c51c57de720dcc496531785a5922db4b739e05d1369bede3bd1c,
                0x03d66d207574b446f1bd7ead7fe1cb04b232c041b4c825d27dd3c710bf24e6c3
            ],
            pubSignals: [
                0x0fb849f7cf35865c838cef48782e803b2c38263e2f467799c87eff168eb4d897
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

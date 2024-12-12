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

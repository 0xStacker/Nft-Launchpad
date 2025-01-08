// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library PresaleLib{
    // Holds data for merkle tree based whitelist phase.
    
    struct PresalePhaseIn{
        uint8 maxPerAddress;
        string name;
        uint price;
        uint startTime;
        uint endTime;
        bytes32 merkleRoot;
    }

    struct PresalePhase{
        uint8 maxPerAddress;
        string name;
        uint price;
        uint startTime;
        uint endTime;
        bytes32 merkleRoot;
        bytes32 phaseId;
    }

    function computePhaseId(PresalePhase memory phase) external pure returns (bytes32)  {
        return keccak256(abi.encodePacked(phase.name,phase.price, phase.startTime, phase.merkleRoot));
    }

    function getId(PresalePhaseIn memory phase) external pure returns (PresalePhase memory){
    } 
}

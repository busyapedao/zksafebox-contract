//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./verifier.sol";
import "hardhat/console.sol";

contract ZkSafebox is Context {

    event SetBoxhash(
        bytes32 indexed boxhash,
        address indexed owner
    );
  
    event Recharge(
        address indexed sender,
        address indexed owner,
        address tokenAddr,
        uint amount
    );

    event Withdraw(
        address indexed owner,
        address indexed to,
        address tokenAddr,
        uint amount
    );

    Verifier verifier = new Verifier();

    struct SafeBox{
        bytes32 boxhash;
        address owner;
        mapping(address => uint) balance;
    }

    mapping(address => SafeBox) public owner2safebox;

    mapping(uint => bool) public usedProof;


    constructor() {}


    function balanceOf(address owner, address[] memory tokenAddrs) public view returns(uint[] memory bals) {
        SafeBox storage box = owner2safebox[owner];
        bals = new uint[](tokenAddrs.length);
        for (uint i=0; i<tokenAddrs.length; i++) {
            address tokenAddr = tokenAddrs[i];
            bals[i] = box.balance[tokenAddr];
        }
    }


    function setBoxhash(
        uint[8] memory proof1,
        uint pswHash1,
        uint allHash1,
        uint[8] memory proof2,
        uint pswHash2,
        uint allHash2,
        bytes32 boxhash2
    ) public {
        SafeBox storage box = owner2safebox[_msgSender()];

        if (box.boxhash != bytes32(0)) { 
            // check old boxhash 
            require(!usedProof[proof1[0]], "ZkSafebox::setBoxhash: proof1 used");
            require(keccak256(abi.encodePacked(pswHash1, _msgSender())) == box.boxhash, "ZkSafebox::setBoxhash: pswHash error");
            require(verifyProof(proof1, pswHash1, address(0), 0, allHash1), "ZkSafebox::setBoxhash: verifyProof1 fail");

            usedProof[proof1[0]] = true;

        }

        require(!usedProof[proof2[0]], "ZkSafebox::setBoxhash: proof2 used");
        require(keccak256(abi.encodePacked(pswHash2, _msgSender())) == boxhash2, "ZkPay::setBoxhash: boxhash2 error");
        require(verifyProof(proof2, pswHash2, address(0), 0, allHash2), "ZkSafebox::setBoxhash: verifyProof2 fail");

        usedProof[proof2[0]] = true;

        box.boxhash = boxhash2;
        if (box.owner == address(0)) {
            //new user
            box.owner = _msgSender();
        }

        emit SetBoxhash(boxhash2, box.owner);
    }


    function recharge(
        address sender,
        address owner,
        address tokenAddr,
        uint amount
    ) public {
        SafeBox storage box = owner2safebox[owner];

        IERC20(tokenAddr).transferFrom(sender, address(this), amount);
        box.balance[tokenAddr] += amount;

        emit Recharge(sender, owner, tokenAddr, amount);
    }


    function withdraw(
        uint[8] memory proof,
        uint pswHash,
        address tokenAddr,
        uint amount,
        uint allHash,
        address to
    ) public {
        require(!usedProof[proof[0]], "ZkSafebox::withdraw: proof used");

        SafeBox storage box = owner2safebox[_msgSender()];
        require(keccak256(abi.encodePacked(pswHash, _msgSender())) == box.boxhash, "ZkSafebox::withdraw: pswHash error");
        require(verifyProof(proof, pswHash, tokenAddr, amount, allHash), "ZkSafebox::withdraw: verifyProof fail");

        usedProof[proof[0]] = true;
        box.balance[tokenAddr] -= amount;

        IERC20(tokenAddr).transfer(to, amount);

        emit Withdraw(box.owner, to, tokenAddr, amount);
    }


    ///////////////////////////////////
    // SocialRecover
    ///////////////////////////////////


    enum CoverChoice { 
        CoverBoxhash, 
        CoverOwner
    }

    struct SocialRecover {
        CoverChoice choice;
        address[] needWallets;
        uint needWalletNum;
        address[] doneWallets;
    }

    mapping(address => mapping(CoverChoice => SocialRecover)) public owner2choice2recover;


    function setSocialRecover(
        uint[8] memory proof,
        uint pswHash,
        uint allHash,
        CoverChoice choice, 
        address[] memory needWallets, 
        uint needWalletNum
    ) public {
        require(needWalletNum > 0, "ZkSafebox::setSocialRecover: needWalletNum must > 0");

        SafeBox storage box = owner2safebox[_msgSender()];

        require(box.boxhash != bytes32(0), "ZkSafebox::setSocialRecover: boxhash not set");
        require(!usedProof[proof[0]], "ZkSafebox::setSocialRecover: proof used");
        require(keccak256(abi.encodePacked(pswHash, _msgSender())) == box.boxhash, "ZkSafebox::setSocialRecover: pswHash error");
        require(verifyProof(proof, pswHash, address(0), 0, allHash), "ZkSafebox::setSocialRecover: verifyProof fail");

        usedProof[proof[0]] = true;

        owner2choice2recover[_msgSender()][choice] = SocialRecover(
            choice,
            needWallets,
            needWalletNum,
            new address[](needWalletNum)
        );
    }


    function coverBoxhash(address owner) public {
        SafeBox storage box = owner2safebox[owner];
        SocialRecover memory recover = owner2choice2recover[owner][CoverChoice.CoverBoxhash];

        uint insertIndex = 9999999;
        for (uint i=0; i<recover.doneWallets.length; ++i) {
            if (insertIndex == 9999999 && recover.doneWallets[i] == address(0)) {
                insertIndex = i;
            }
            require(recover.doneWallets[i] != _msgSender(), "ZkSafebox::coverBoxhash: don't repeat");
        }
        
        bool isNeedWallet;
        console.log("[coverBoxhash]", recover.needWallets.length);
        for (uint j=0; j<recover.needWallets.length; ++j) {
            if (recover.needWallets[j] == _msgSender()) {
                isNeedWallet = true;
                break;
            }
        }
        require(isNeedWallet, "ZkSafebox::coverBoxhash: you're not in needWallets");

        if (insertIndex == recover.needWalletNum - 1) {
            //fire!
            box.boxhash = bytes32(0);
            delete owner2choice2recover[owner][CoverChoice.CoverBoxhash];
        } else {
            owner2choice2recover[owner][CoverChoice.CoverBoxhash].doneWallets[insertIndex] = _msgSender();
        }
    }
    
    
    function coverOwner(address owner, address newOwner) public {
        SafeBox storage box = owner2safebox[owner];
        SocialRecover memory recover = owner2choice2recover[owner][CoverChoice.CoverOwner];

        require(box.boxhash == bytes32(0), "ZkSafebox::coverOwner: need cover boxhash first");

        uint insertIndex = 9999999;
        for (uint i=0; i<recover.doneWallets.length; ++i) {
            if (insertIndex == 9999999 && recover.doneWallets[i] == address(0)) {
                insertIndex = i;
            }
            require(recover.doneWallets[i] != _msgSender(), "ZkSafebox::coverOwner: don't repeat");
        }
        
        bool isNeedWallet;
        for (uint j=0; j<recover.needWallets.length; ++j) {
            if (recover.needWallets[j] == _msgSender()) {
                isNeedWallet = true;
                break;
            }
        }
        require(isNeedWallet, "ZkSafebox::coverOwner: you're not in needWallets");

        if (insertIndex == recover.needWalletNum - 1) {
            //fire!
            box.owner = newOwner;
            delete owner2choice2recover[owner][CoverChoice.CoverOwner];
        } else {
            owner2choice2recover[owner][CoverChoice.CoverOwner].doneWallets[insertIndex] = _msgSender();
        }
    }


    /////////// util ////////////

    function verifyProof(
        uint[8] memory proof,
        uint pswHash,
        address tokenAddr,
        uint amount,
        uint allHash
    ) internal view returns (bool) {
        return verifier.verifyProof(
            [proof[0], proof[1]],
            [[proof[2], proof[3]], [proof[4], proof[5]]],
            [proof[6], proof[7]],
            [pswHash, uint160(tokenAddr), amount, allHash]
        );
    }

}
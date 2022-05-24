//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./interfaces/IERC20Receiver.sol";
import "./verifier.sol";
import "hardhat/console.sol";

contract ZkSafebox is Context {

    using SafeERC20 for IERC20;

    event SetBoxhash(
        bytes32 indexed boxhash,
        address indexed owner
    );
  
    event Deposit(
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

    mapping(uint => bool) internal usedProof;


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


    function deposit(
        address sender,
        address owner,
        address tokenAddr,
        uint amount
    ) public {
        SafeBox storage box = owner2safebox[owner];

        box.balance[tokenAddr] += amount;
        IERC20(tokenAddr).safeTransferFrom(sender, address(this), amount);

        emit Deposit(sender, owner, tokenAddr, amount);
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

        IERC20(tokenAddr).safeTransfer(to, amount);

        emit Withdraw(box.owner, to, tokenAddr, amount);
    }
    
    
    function withdrawToERC20Receiver (
        uint[8] memory proof,
        uint pswHash,
        address tokenAddr,
        uint amount,
        uint allHash,
        address to,
        bytes calldata data
    ) public {
        require(!usedProof[proof[0]], "ZkSafebox::withdraw: proof used");

        SafeBox storage box = owner2safebox[_msgSender()];
        require(keccak256(abi.encodePacked(pswHash, _msgSender())) == box.boxhash, "ZkSafebox::withdraw: pswHash error");
        require(verifyProof(proof, pswHash, tokenAddr, amount, allHash), "ZkSafebox::withdraw: verifyProof fail");

        usedProof[proof[0]] = true;
        box.balance[tokenAddr] -= amount;

        IERC20(tokenAddr).safeTransfer(to, amount);
        IERC20Receiver(to).onERC20Received(_msgSender(), address(this), amount, data);

        emit Withdraw(box.owner, to, tokenAddr, amount);
    }


    function transfer(
        uint[8] memory proof,
        uint pswHash,
        address tokenAddr,
        uint amount,
        uint allHash,
        address toOwner
    ) public {
        require(!usedProof[proof[0]], "ZkSafebox::withdraw: proof used");

        SafeBox storage box = owner2safebox[_msgSender()];
        require(keccak256(abi.encodePacked(pswHash, _msgSender())) == box.boxhash, "ZkSafebox::withdraw: pswHash error");
        require(verifyProof(proof, pswHash, tokenAddr, amount, allHash), "ZkSafebox::withdraw: verifyProof fail");

        usedProof[proof[0]] = true;
        box.balance[tokenAddr] -= amount;
        SafeBox storage toBox = owner2safebox[toOwner];
        toBox.balance[tokenAddr] += amount;

        emit Withdraw(box.owner, toOwner, tokenAddr, amount);
        emit Deposit(toOwner, toOwner, tokenAddr, amount);
    }


    ///////////////////////////////////
    // SocialRecover
    ///////////////////////////////////


    event SetSocialRecover(
        address indexed owner, 
        CoverChoice choice,
        uint needWalletNum
    );

    event Cover(
        address indexed operator,
        address indexed owner,
        uint doneNum
    );


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


    function getRecoverWallets(
        address owner, 
        CoverChoice choice
    ) public view returns (address[] memory needWallets, address[] memory doneWallets) {
        SocialRecover memory recover = owner2choice2recover[owner][choice];
        return (recover.needWallets, recover.doneWallets);
    }


    function setSocialRecover(
        uint[8] memory proof,
        uint pswHash,
        uint allHash,
        CoverChoice choice,
        address[] memory needWallets,
        uint needWalletNum
    ) public {
        require(needWalletNum > 0 && needWalletNum <= needWallets.length, "ZkSafebox::setSocialRecover: needWalletNum error");

        SafeBox storage box = owner2safebox[_msgSender()];
        require(box.boxhash != bytes32(0), "ZkSafebox::setSocialRecover: boxhash not set");

        if (choice == CoverChoice.CoverOwner) {
            require(
                owner2choice2recover[_msgSender()][CoverChoice.CoverBoxhash].needWalletNum > 0, 
                "ZkSafebox::setSocialRecover: need setSocialRecover CoverBoxhash first"
            );
        }

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

        emit SetSocialRecover(_msgSender(), choice, needWalletNum);
    }


    function coverBoxhash(address owner) public {
        SafeBox storage box = owner2safebox[owner];
        SocialRecover memory recover = owner2choice2recover[owner][CoverChoice.CoverBoxhash];

        uint insertIndex;
        bool insertIndexOnce;
        for (uint i=0; i<recover.doneWallets.length; ++i) {
            if (!insertIndexOnce && recover.doneWallets[i] == address(0)) {
                insertIndex = i;
                insertIndexOnce = true;
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

        emit Cover(_msgSender(), owner, insertIndex+1);
    }
    
    
    function coverOwner(address owner, address newOwner) public {
        SafeBox storage box = owner2safebox[owner];
        SocialRecover memory recover = owner2choice2recover[owner][CoverChoice.CoverOwner];

        require(box.boxhash == bytes32(0), "ZkSafebox::coverOwner: need cover boxhash first");

        uint insertIndex = 0;
        bool insertIndexOnce;
        for (uint i=0; i<recover.doneWallets.length; ++i) {
            if (!insertIndexOnce && recover.doneWallets[i] == address(0)) {
                insertIndex = i;
                insertIndexOnce = true;
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

        emit Cover(_msgSender(), owner, insertIndex+1);
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
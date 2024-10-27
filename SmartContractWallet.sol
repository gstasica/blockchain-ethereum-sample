//SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

contract Consumer {

    function getBalance() public view returns(uint){
        return address(this).balance;
    }

    function deposit() public payable {}
}

contract SmartContractWallet {

    address payable public owner;

    mapping(address => uint) allowance;
    mapping(address => bool) isAllowedToSend;
    mapping(address => bool) guardians; //guardians allows us to recover access to the wallet in case of loosing private kye/credentials

    address payable nextOwner;
    uint guardianResetCount;
    uint public constant confirmationRequiredFromGuardianForOwnerReset = 3;
    mapping(address => mapping(address=> bool)) nextOwnerGuardianVotedBool;

    constructor(){
        owner = payable(msg.sender);
    }

    //the following allows to receive money from anyone
    receive() external payable { }

    function setGuardian(address _guardian, bool isGuardian) public {
        require(msg.sender==owner, "Only owner can set guardians, aborting");
        guardians[_guardian] = isGuardian;
    }

    function proposeNewOnwer(address payable _newOwner) public {
        require(guardians[msg.sender], "Only guardians can propose new owners, aborting");
        require(nextOwnerGuardianVotedBool[_newOwner][msg.sender]==false, "You have already voted, aborting");
        
        if(_newOwner!=nextOwner){
            nextOwner=_newOwner;
            guardianResetCount =0;
            nextOwnerGuardianVotedBool[_newOwner][msg.sender]=true;
        }

        guardianResetCount++;

        if(guardianResetCount>=confirmationRequiredFromGuardianForOwnerReset){
            owner = nextOwner;
            nextOwner = payable(address(0));
        }
    }

    //function allows to transfer ether between accounts, including contracts
    function transfer(address payable _to, uint _amount, bytes memory _payload) public returns (bytes memory) {
        // require(msg.sender==owner, "Only owner can transfer money from this wallet");
        if(msg.sender!=owner){
            require(isAllowedToSend[msg.sender], "You're not allowed to send anything from this smart contract, aborting");
            require(allowance[msg.sender]>=_amount, "You're trying to send more than allowed, aborting.");

            allowance[msg.sender]-= _amount;
        }

        //'call' function allows to transfer ether between contracts
        (bool success, bytes memory returnData) = _to.call{value: _amount}(_payload);
        require(success, "The call was not sucessfull, aborting");
        return returnData;
    }

    function setAllowance(address _for, uint _allowance) public{
        require(msg.sender==owner, "Only smart contract owner can set allowance, aborting");
        allowance[_for] = _allowance;

        if(_allowance>0){
            isAllowedToSend[_for] = true;
        }else {
            isAllowedToSend[_for] = false; 
        }
    }


}
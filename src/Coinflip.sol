// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DirectFundingConsumer} from "./DirectFundingConsumer.sol";

contract Coinflip is Ownable{
    // A map of the player and their corresponding requestId
    mapping(address => uint256) public playerRequestID;
    // A map that stores the player's 3 Coinflip guesses
    mapping(address => uint8[3]) public bets;
    // An instance of the random number requestor, client interface
    DirectFundingConsumer private vrfRequestor;

    ///@dev we no longer use the seed, instead each coinflip deployment should spawn its own VRF instance so that the Coinflip smart contract is the owner of the DirectFunding contract.
    ///@notice This programming pattern is known as a factory model - a contract creating other contracts 
    constructor() Ownable(msg.sender) {
        vrfRequestor = new DirectFundingConsumer();
    }

    ///@notice Fund the VRF instance with **5** LINK tokens.
    ///@return boolean of whether funding the VRF instance with link tokens was successful or not
    ///@dev use the address of LINK token contract provided. Do not change the address!
    ///@custom:note In order for this contract to fund another contract, which tokens does this contract need to have before calling this function? What **additional** functions does this contract need to "receive" these tokens itself?
  function fundOracle() external returns (bool) {
    address Link_addr = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    uint256 amount = 5 * 10**18;
    IERC20 linkToken = IERC20(Link_addr);
    require(linkToken.balanceOf(address(this)) >= amount, "Insufficient LINK balance");
    require(linkToken.transfer(address(vrfRequestor), amount), "LINK transfer failed");

    return true;
}

    ///@notice Allows the user to guess three flips, choosing either 1 or 0.
   ///@param Guesses An array of three guesses, each required to be 1 or 0.
   ///@dev After validating the user input, stores the guesses in the mapping and requests 3 random numbers from the VRF.
  ///@custom:note Ensure that exactly 3 random numbers are requested.
  ///@dev Stores the request ID in the global mapping.

    function userInput(uint8[3] memory Guesses) external {
        // Ensure all guesses are either 0 or 1
    for (uint8 i = 0; i < 3; i++) {
        require(Guesses[i] == 0 || Guesses[i] == 1, "Invalid guess: must be 0 or 1");
    }
    // Store user guesses in mapping
    bets[msg.sender] = Guesses;

    // Request three random numbers from VRF
    uint256 requestId = vrfRequestor.requestRandomWords(false); 
    // Store the request ID for the user
    playerRequestID[msg.sender] = requestId;
    }

    ///@notice Due to the fact that a blockchain does not deliver data instantaneously, in fact quite slowly under congestion, allow users to check the status of their request.
    ///@return boolean of whether the request has been fulfilled or not
    function checkStatus() external view returns(bool){
        uint256 requestId = playerRequestID[msg.sender];
        (, bool fulfilled, ) = vrfRequestor.getRequestStatus(requestId);
        return fulfilled;
    }

    ///@return boolean of whether the user won or not based on their input
    ///@dev Check if whether each of the three random numbers is even or odd. If it is even, the randomly generated flip is 0 and if it is odd, the random flip is 1.
    ///@notice Player wins if the 1, 0 flips of the contract matches the 3 guesses of the player.
    function determineFlip() external view returns(bool){
        uint256 requestId = playerRequestID[msg.sender];
        (, bool fulfilled, uint256[] memory randomWords) = vrfRequestor.getRequestStatus(requestId);
        require(fulfilled, "Request not fulfilled yet");

        uint8[3] memory playerGuesses = bets[msg.sender];
        uint8 wins = 0;

        for (uint8 i = 0; i < 3; i++) {
            uint8 flip = uint8(randomWords[i] % 2);
            if (flip == playerGuesses[i]) {
                wins++;
            }
        }
        return wins >= 2;
    }

}
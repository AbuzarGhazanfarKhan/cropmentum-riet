// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*
  REITFactory
  - Deploys REITToken instances using simple CREATE (for clarity).
  - Keeps registry of created REIT tokens and metadata.
  - Factory owner (platform) can be admin to perform administrative tasks or flag tokens.
  - Now supports vesting for company shares (5 days lock)
*/

import "./REITToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract REITFactory is Ownable {
    address public company; // platform/company address receiving 30% at creation

    struct REITInfo {
        address tokenAddress;
        address issuer;
        string name;
        string symbol;
        uint256 totalSupply;
        uint256 createdAt;
    }

    REITInfo[] public reits;
    mapping(address => bool) public isREIT;

    event REITCreated(address indexed token, address indexed issuer, uint256 indexed idx);

    constructor(address company_) {
        require(company_ != address(0), "company zero");
        company = company_;
    }

    function setCompany(address company_) external onlyOwner {
        require(company_ != address(0), "company zero");
        company = company_;
    }

    // create a new REIT token; issuer pays gas; supply in token smallest units
    function createREIT(
        string calldata name_,
        string calldata symbol_,
        uint256 totalSupply_,   // e.g. 1_000_000 * 10**18
        address issuerAddress_
    ) external returns (address) {
        require(issuerAddress_ != address(0), "issuer zero");
        require(totalSupply_ > 0, "supply zero");

        // Deploy new token
        REITToken token = new REITToken(
            name_,
            symbol_,
            totalSupply_,
            company,
            issuerAddress_
        );

        address tokenAddr = address(token);
        reits.push(REITInfo({
            tokenAddress: tokenAddr,
            issuer: issuerAddress_,
            name: name_,
            symbol: symbol_,
            totalSupply: totalSupply_,
            createdAt: block.timestamp
        }));

        isREIT[tokenAddr] = true;
        emit REITCreated(tokenAddr, issuerAddress_, reits.length - 1);
        return tokenAddr;
    }

    // view count
    function reitCount() external view returns (uint256) {
        return reits.length;
    }

    // Owner can mark a token as suspicious/unlist (not implemented here—could add flags)
}

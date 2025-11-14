// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*
  REITFactory
  - Deploys REITToken clones using EIP-1167 minimal proxy for gas efficiency.
  - Keeps registry of created REIT tokens and metadata.
  - Factory owner (platform) can be admin to perform administrative tasks or flag tokens.
  - Now supports vesting for company shares (5 days lock)
  - Uses clone pattern to reduce deployment costs for multiple REITs
*/

import "./REITToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract REITFactory is Ownable {
    address public company; // platform/company address receiving 25% at creation
    address public masterContract; // master REITToken for cloning

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
    event MasterSet(address indexed master);

    constructor(address company_) {
        require(company_ != address(0), "company zero");
        company = company_;
        // Deploy master contract
        masterContract = address(new REITToken());
        emit MasterSet(masterContract);
    }

    function setCompany(address company_) external onlyOwner {
        require(company_ != address(0), "company zero");
        company = company_;
    }

    // Clone function for EIP-1167
    function clone(address implementation) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), implementation)
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "clone failed");
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

        // Clone the master contract
        address tokenAddr = clone(masterContract);

        // Initialize the clone
        REITToken(tokenAddr).initialize(name_, symbol_, totalSupply_, company, issuerAddress_);

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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*
  REITFactory
  - Simple factory that deploys REITVault instances.
  - Owner is the platform multisig. Company address is provided per factory.
  - Could be adapted to use EIP-1167 clones for gas optimization.
*/

import "./REITVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract REITFactory is Ownable {
    address public company;

    struct VaultInfo {
        address vault;
        address issuer;
        string name;
        string symbol;
        address asset; // underlying (e.g., USDC)
        uint256 createdAt;
    }

    VaultInfo[] public vaults;
    mapping(address => bool) public isVault;

    event VaultCreated(address indexed vault, address indexed issuer, uint256 indexed idx);

    constructor(address company_) {
        require(company_ != address(0), "company zero");
        company = company_;
    }

    function setCompany(address company_) external onlyOwner {
        require(company_ != address(0), "company zero");
        company = company_;
    }

    // create a new REITVault; issuer pays gas; owner/admin remains the factory owner (platform)
    function createVault(
        address asset_,   // ERC20 underlying, e.g., USDC
        string calldata name_,
        string calldata symbol_,
        address issuer_
    ) external returns (address) {
        require(asset_ != address(0), "asset zero");
        require(issuer_ != address(0), "issuer zero");

        REITVault vault = new REITVault(
            ERC20(asset_),
            name_,
            symbol_,
            company,
            issuer_
        );

        vaults.push(VaultInfo({
            vault: address(vault),
            issuer: issuer_,
            name: name_,
            symbol: symbol_,
            asset: asset_,
            createdAt: block.timestamp
        }));

        isVault[address(vault)] = true;
        emit VaultCreated(address(vault), issuer_, vaults.length - 1);
        return address(vault);
    }

    function vaultCount() external view returns (uint256) {
        return vaults.length;
    }
}

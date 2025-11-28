// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*
  REITFactory
  - Clone factory using EIP-1167 for gas-efficient vault deployments.
  - Deploys REITVault clones from a master contract.
  - Owner is the platform multisig. Company address is provided per factory.
  - Uses minimal proxies to reduce deployment costs.
*/

import "./REITVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract REITFactory is Ownable {
    address public company;
    address public masterContract; // master REITVault for cloning

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
    event MasterSet(address indexed master);

    constructor(address company_) {
        require(company_ != address(0), "company zero");
        company = company_;
        // Deploy master contract (uninitialized)
        masterContract = address(new REITVault());
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

    // create a new REITVault; issuer pays gas; uses clone for efficiency
    function createVault(
        address asset_,   // ERC20 underlying, e.g., USDC
        string calldata name_,
        string calldata symbol_,
        address issuer_,
        bytes32 merkleRoot_ // for KYC whitelist
    ) external returns (address) {
        require(asset_ != address(0), "asset zero");
        require(issuer_ != address(0), "issuer zero");

        // Clone the master contract
        address vaultAddr = clone(masterContract);

        // Initialize the clone
        REITVault(vaultAddr).initialize(
            ERC20(asset_),
            name_,
            symbol_,
            company,
            issuer_,
            merkleRoot_
        );

        vaults.push(VaultInfo({
            vault: vaultAddr,
            issuer: issuer_,
            name: name_,
            symbol: symbol_,
            asset: asset_,
            createdAt: block.timestamp
        }));

        isVault[vaultAddr] = true;
        emit VaultCreated(vaultAddr, issuer_, vaults.length - 1);
        return vaultAddr;
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

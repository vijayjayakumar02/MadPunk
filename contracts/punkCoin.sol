// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./common/ERC20.sol";
import "./common/ERC20Burnable.sol";
import "./security/Pausable.sol";
import "./access/AccessControl.sol";


contract PunkCoin is ERC20, ERC20Burnable, Pausable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // variable to store max supply of tokens as 240 million tokens
    uint256 private immutable _MAX_SUPPLY = 240000000 * 10**18;

    // variable to store governance wallet address
    address public governanceWallet;

    constructor() ERC20("Punk Coin", "PC") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        governanceWallet = msg.sender;
        _mint(msg.sender, 1000000 * 10**decimals());
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= _MAX_SUPPLY, "Max supply exceeded");
        _mint(to, amount);
    }

    function MAX_SUPPLY() public view virtual returns (uint256) {
        return _MAX_SUPPLY;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}

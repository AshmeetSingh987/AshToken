// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AshToken is ERC20 {
    constructor() ERC20("Qoodo", "QDO") {
        _mint(msg.sender, 1000000000000000000000000000 * 10 ** decimals());
    }
}

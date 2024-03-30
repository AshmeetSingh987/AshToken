// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenVesting is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        uint256 amount;
        uint256 claimed;
        uint256 startTime;
        uint256 cliff;
        uint256 vestingDuration;
        uint256 initialRelease;
    }

    IERC20 private immutable _token;
    mapping(address => VestingSchedule) private _vestingSchedules;
    uint256 private _totalAllocated;
    bool private _claimAllowed;

    event VestingAdded(address indexed payee, uint256 amount);
    event TokensClaimed(address indexed payee, uint256 amount);
    event VestingRevoked(address indexed payee);

    constructor(address token, address initalOwner) Ownable(initalOwner) {
        _token = IERC20(token);
        _claimAllowed = false;
    }

    function addVestingSchedule(
        address payee,
        uint256 amount,
        uint256 startTime,
        uint256 cliff,
        uint256 vestingDuration,
        uint256 initialRelease
    ) external onlyOwner {
        require(payee != address(0), "TokenVesting: zero address");
        require(amount > 0, "TokenVesting: zero amount");
        require(
            _vestingSchedules[payee].amount == 0,
            "TokenVesting: existing vesting schedule"
        );
        require(vestingDuration > 0, "TokenVesting: zero vesting duration");
        require(
            cliff <= vestingDuration,
            "TokenVesting: cliff larger than vesting duration"
        );
        require(
            initialRelease <= amount,
            "TokenVesting: initial release larger than amount"
        );
        require(
            initialRelease <= (amount * cliff) / vestingDuration,
            "TokenVesting: initial release larger than cliff allocation"
        );

        _vestingSchedules[payee] = VestingSchedule({
            amount: amount,
            claimed: 0,
            startTime: startTime,
            cliff: cliff,
            vestingDuration: vestingDuration,
            initialRelease: initialRelease
        });

        _totalAllocated = _totalAllocated.add(amount);

        emit VestingAdded(payee, amount);
    }

    function revokeVestingSchedule(address payee) external onlyOwner {
        VestingSchedule storage vestingSchedule = _vestingSchedules[payee];
        require(
            vestingSchedule.amount > 0,
            "TokenVesting: no vesting schedule found"
        );

        uint256 remainingAmount = vestingSchedule.amount.sub(
            vestingSchedule.claimed
        );
        _totalAllocated = _totalAllocated.sub(remainingAmount);
        _token.safeTransfer(owner(), remainingAmount);
        delete _vestingSchedules[payee];

        emit VestingRevoked(payee);
    }

    function claim(uint256 amount) external {
        require(_claimAllowed == true, "TokenVesting: claiming not allowed");
        require(
            amount <= _token.balanceOf(address(this)),
            "TokenVesting: insufficient balance"
        );

        address payee = msg.sender;
        VestingSchedule storage vestingSchedule = _vestingSchedules[payee];
        require(
            vestingSchedule.amount > 0,
            "TokenVesting: no vesting schedule found"
        );

        uint256 claimableTokens = calculateClaimableAmount(payee);
        require(
            amount <= claimableTokens,
            "TokenVesting: cannot claim more than vested amount"
        );

        vestingSchedule.claimed = vestingSchedule.claimed.add(amount);
        _token.safeTransfer(payee, amount);

        emit TokensClaimed(payee, amount);
    }

    function calculateClaimableAmount(
        address payee
    ) public view returns (uint256) {
        VestingSchedule memory vestingSchedule = _vestingSchedules[payee];

        if (block.timestamp < vestingSchedule.startTime) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp.sub(vestingSchedule.startTime);
        uint256 vestedAmount;

        if (elapsedTime < vestingSchedule.cliff) {
            vestedAmount = vestingSchedule.initialRelease;
        } else if (
            elapsedTime >= vestingSchedule.vestingDuration || elapsedTime == 0
        ) {
            vestedAmount = vestingSchedule.amount;
        } else {
            uint256 totalVestingTime = vestingSchedule.vestingDuration.sub(
                vestingSchedule.cliff
            );
            uint256 timeSinceCliff = elapsedTime.sub(vestingSchedule.cliff);
            vestedAmount = vestingSchedule.initialRelease.add(
                vestingSchedule
                    .amount
                    .sub(vestingSchedule.initialRelease)
                    .mul(timeSinceCliff)
                    .div(totalVestingTime)
            );
        }

        if (vestedAmount < vestingSchedule.claimed) {
            return 0;
        }

        return vestedAmount.sub(vestingSchedule.claimed);
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(
            amount <= _token.balanceOf(address(this)),
            "TokenVesting: insufficient balance"
        );
        _token.safeTransfer(owner(), amount);
    }

    function withdrawAll() external onlyOwner {
        _token.safeTransfer(owner(), _token.balanceOf(address(this)));
    }

    function setClaimAllowed(bool allowed) external onlyOwner {
        _claimAllowed = allowed;
    }

    function getVestingSchedule(
        address payee
    )
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        VestingSchedule memory vestingSchedule = _vestingSchedules[payee];
        return (
            vestingSchedule.amount,
            vestingSchedule.claimed,
            vestingSchedule.startTime,
            vestingSchedule.cliff,
            vestingSchedule.vestingDuration,
            vestingSchedule.initialRelease
        );
    }

    function token() external view returns (address) {
        return address(_token);
    }

    function totalAllocated() external view returns (uint256) {
        return _totalAllocated;
    }

    function claimAllowed() external view returns (bool) {
        return _claimAllowed;
    }
}

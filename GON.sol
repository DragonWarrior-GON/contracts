// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract GON is ERC20PresetMinterPauser {
    
    struct LockBot {
        bool locked;
        uint256 lockedFrom;
        uint256 initLockedBalance;
        bool hardLock;
    }
    
    
    mapping(address => LockBot) private _listBot;
    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");
    uint256 public constant MAX_SUPPLY = 10 * (10 ** 6) * (10 ** 18);
    uint256 public constant LOCK_BOT_DAYS = 60;
    
    
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "GON: ADMIN role required");
        _;
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), "GON: MINTER role required");
        _;
    }

    modifier onlyLocker() {
        require(hasRole(LOCKER_ROLE, _msgSender()), "GON: LOCKER role required");
        _;
    }
    
    constructor() ERC20PresetMinterPauser("Dragon Warrior", "GON") {
        // _mint(_msgSender(), MAX_SUPPLY);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(LOCKER_ROLE, _msgSender());
    }
    
    
    function mint(address to, uint256 amount) public virtual override onlyMinter {
        require(totalSupply() + amount <= MAX_SUPPLY, "GON: Max supply exceeded");
        _mint(to, amount);
    }
    
    function isBot(address bot) external view returns (bool) {
        return _listBot[bot].locked;
    }

    function getLockBot(address bot) external view returns (LockBot memory) {
        return _listBot[bot];
    }

    function addToListBotNormal(address bot) external onlyLocker {
        _listBot[bot] = LockBot(true, block.timestamp, balanceOf(bot), false);
    }
    
    function addToListBotHardLock(address bot) external onlyLocker {
        _listBot[bot] = LockBot(true, block.timestamp, balanceOf(bot), true);
    }

    function removeLockBot(address bot) external onlyLocker {
        _listBot[bot].locked = false;
        _listBot[bot].hardLock = false;
    }

    function _getBalanceUnlocked(address bot) internal view returns (uint256 unlockedBalance) {
        LockBot memory info = _listBot[bot];
        uint256 daysPassed = (block.timestamp - info.lockedFrom) / 1 days;

        if (info.locked && daysPassed < LOCK_BOT_DAYS) {
            unlockedBalance = (daysPassed * info.initLockedBalance) / LOCK_BOT_DAYS;
        } else {
            unlockedBalance = info.initLockedBalance;
        }
        return unlockedBalance;
    }

    function remainBalanceLocked(address bot) public view returns (uint256) {
        return _listBot[bot].initLockedBalance - _getBalanceUnlocked(bot);
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        if (_listBot[from].locked) {
            uint256 lockedBalance = remainBalanceLocked(from);
            require(
                !_listBot[from].hardLock && (balanceOf(from) - amount) >= lockedBalance,
                "GON: bot cannot transfer locked balance"
            );
        }
    }


    function withdrawERC20(address token, uint256 amount) external onlyAdmin {
        require(amount > 0, "GON: Amount must be greater than 0");
        require(IERC20(token).balanceOf(address(this)) >= amount, "GON: ERC20 not enough balance");
        require(IERC20(token).transfer(_msgSender(), amount), "GON: transfer ERC20 failed");
    }

    receive() external payable {
        revert();
    }
}
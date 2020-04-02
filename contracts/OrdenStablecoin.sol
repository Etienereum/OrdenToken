pragma solidity 0.5.8;


/**
 * @title SafeMath
 *
 * @dev SafeMath Library - General Math Utility Library for safe Math operations
 * with safety checks that throws error
 */
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        require(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }
}


/**
 * @title Owned
 *
 * @dev Owned contract - Implements a simple ownership model with 2-phase transfer.It sets
 * the owner and the ownership control. Also, it can transfer the ownership to a new owner,
 * a proposedOwner, to be able to have authorization and control functions, this simplifies
 * the implementation of "user permissions".
 */
contract Owned {
    address public owner;
    address public proposedOwner;

    event OwnershipTransferInitiated(address indexed _proposedOwner);
    event OwnershipTransferCompleted(address indexed _newOwner);
    event OwnershipTransferCanceled();

    /**
     * @dev The Owned constructor sets the original `owner` of the contract to the
     * creator's account.
     */
    constructor() public {
        owner = msg.sender;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(msg.sender) == true);
        _;
    }

    function isOwner(address _address) public view returns (bool) {
        return (_address == owner);
    }

    /**
     * @dev Allows the owner to initiate and Ownership control of the contract to a newOwner.
     *
     * @param _proposedOwner - The address to initiateOwnershipTransfer to.
     */
    function initiateOwnershipTransfer(address _proposedOwner)
        public
        onlyOwner
        returns (bool)
    {
        require(_proposedOwner != address(0));
        require(_proposedOwner != address(this));
        require(_proposedOwner != owner);

        proposedOwner = _proposedOwner;

        emit OwnershipTransferInitiated(proposedOwner);

        return true;
    }

    /**
     * @dev Allows for the cancellation of the OwnershipTransfer
     */
    function cancelOwnershipTransfer() public onlyOwner returns (bool) {
        if (proposedOwner == address(0)) {
            return true;
        }

        proposedOwner = address(0);

        emit OwnershipTransferCanceled();

        return true;
    }

    /**
     * @dev Allows for the finalization of the initiated Ownership Transfer
     */
    function completeOwnershipTransfer() public returns (bool) {
        require(msg.sender == proposedOwner);

        owner = msg.sender;
        proposedOwner = address(0);

        emit OwnershipTransferCompleted(owner);

        return true;
    }
}


/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Owned {
    event Pause();
    event Unpause();

    bool public paused = false;

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpause();
    }
}


/**
 * @title ERC20Interface - Standard ERC20 Interface Definition based on the final specification at:
 * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
 *
 * @dev Also, you can see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20Interface {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    //   function name() public view returns (string memory);
    //   function symbol() public view returns (string memory);
    //   function decimals() public view returns (uint8);
    uint256 public _totalSupply;

    function totalSupply() public view returns (uint256);

    function balanceOf(address _owner) public view returns (uint256);

    function allowance(address _owner, address _spender)
        public
        view
        returns (uint256 remaining);

    // function balanceOf(address who) public view returns (uint256);
    // function transfer(address to, uint256 value) public;

    function transfer(address _to, uint256 _value) public;

    function transferFrom(address _from, address _to, uint256 _value)
        public
        returns (bool success);

    function approve(address _spender, uint256 _value)
        public
        returns (bool success);
}


/**
 * @title ERC20Token - Standard ERC20 Implementation
 */
contract ERC20Token is Owned, ERC20Interface {
    using SafeMath for uint256;

    uint256 public basisPointsRate = 0;
    uint256 public maximumFee = 0;

    mapping(address => uint256) internal balances;

    modifier onlyPayloadSize(uint256 size) {
        require(!(msg.data.length < size + 4));
        _;
    }

    // function balanceOf(address _owner) public view returns (uint256 balance);

    // function transfer(address _to, uint256 _value) public returns (bool success);

    function transfer(address _to, uint256 _value)
        public
        onlyPayloadSize(2 * 32)
    {
        uint256 fee = (_value.mul(basisPointsRate)).div(10000);
        if (fee > maximumFee) {
            fee = maximumFee;
        }
        uint256 sendAmount = _value.sub(fee);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(sendAmount);
        if (fee > 0) {
            balances[owner] = balances[owner].add(fee);
            emit Transfer(msg.sender, owner, fee);
        }
        emit Transfer(msg.sender, _to, sendAmount);
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param _owner The address to query the the balance of.
     * @return An uint representing the amount owned by the passed address.
     */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
}


contract StandardToken is ERC20Token {
    mapping(address => mapping(address => uint256)) public allowed;

    uint256 public constant MAX_UINT = 2**256 - 1;

    function transferFrom(address _from, address _to, uint256 _value)
        public
        onlyPayloadSize(3 * 32)
        returns (bool sucess)
    {
        uint256 _allowance = allowed[_from][msg.sender];

        uint256 fee = (_value.mul(basisPointsRate)).div(10000);
        if (fee > maximumFee) {
            fee = maximumFee;
        }
        if (_allowance < MAX_UINT) {
            allowed[_from][msg.sender] = _allowance.sub(_value);
        }
        uint256 sendAmount = _value.sub(fee);
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(sendAmount);
        if (fee > 0) {
            balances[owner] = balances[owner].add(fee);
            emit Transfer(_from, owner, fee);
        }
        emit Transfer(_from, _to, sendAmount);

        return true;
    }

    function approve(address _spender, uint256 _value)
        public
        onlyPayloadSize(2 * 32)
        returns (bool sucess)
    {
        require(!((_value != 0) && (allowed[msg.sender][_spender] != 0)));

        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);

        return true;
    }

    function allowance(address _owner, address _spender)
        public
        view
        returns (uint256 remaining)
    {
        return allowed[_owner][_spender];
    }
}


contract BlackList is Owned, ERC20Token {
    mapping(address => bool) public isBlackListed;

    event AddedBlackList(address _user);
    event RemovedBlackList(address _user);
    event DestroyedBlackFunds(address _blackListedUser, uint256 _balance);

    // Getters to allow the same blacklist to be used also by other contracts
    function getBlackListStatus(address _maker) external view returns (bool) {
        return isBlackListed[_maker];
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function addBlackList(address _evilUser) public onlyOwner {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    function removeBlackList(address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    function destroyBlackFunds(address _blackListedUser) public onlyOwner {
        require(isBlackListed[_blackListedUser]);
        uint256 dirtyFunds = balanceOf(_blackListedUser);
        balances[_blackListedUser] = 0;
        _totalSupply -= dirtyFunds;
        emit DestroyedBlackFunds(_blackListedUser, dirtyFunds);
    }
}


/**
 * These methods are called by the legacy contract
 * and they must ensure msg.sender to be the contract address
 */
contract UpgradedERC20Token is ERC20Token {
    function transferByLegacy(address from, address to, uint256 value) public;

    function transferFromByLegacy(
        address sender,
        address from,
        address spender,
        uint256 value
    ) public;

    function approveByLegacy(address from, address spender, uint256 value)
        public;
}


/**
 * ERC20 Compatible Stable Coin
 * The token is a standard ERC20 Stable  with the addition of a few
 * concepts such as:
 */
contract PHStableCoin is Pausable, StandardToken, BlackList {
    string internal tokenName;
    string internal tokenSymbol;
    uint8 internal tokenDecimals;
    uint256 internal tokenTotalSupply;
    uint256 internal decimalsfactor = 10**uint256(tokenDecimals);

    bool public deprecated;
    address public upgradedAddress;

    event Issue(uint256 amount);
    event Redeem(uint256 amount);
    event Deprecate(address newAddress);
    event Params(uint256 feeBasisPoints, uint256 maxFee);

    constructor(uint256 _initialSupply) public {
        tokenName = "PharmHedge Stablecoin";
        tokenSymbol = "PHSC";
        tokenDecimals = 18;
        tokenTotalSupply = _initialSupply;

        balances[owner] = _initialSupply;
        deprecated = false;
    }

    function name() public view returns (string memory) {
        return tokenName;
    }

    function symbol() public view returns (string memory) {
        return tokenSymbol;
    }

    function decimals() public view returns (uint8) {
        return tokenDecimals;
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function transfer(address _to, uint256 _value) public whenNotPaused {
        require(!isBlackListed[msg.sender]);
        if (deprecated) {
            UpgradedERC20Token(upgradedAddress).transferByLegacy(
                msg.sender,
                _to,
                _value
            );
        } else {
            super.transfer(_to, _value);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function transferFrom(address _from, address _to, uint256 _value)
        public
        whenNotPaused
        returns (bool sucess)
    {
        require(!isBlackListed[_from]);
        if (deprecated) {
            UpgradedERC20Token(upgradedAddress).transferFromByLegacy(
                msg.sender,
                _from,
                _to,
                _value
            );
        } else {
            super.transferFrom(_from, _to, _value);
        }
        return true;
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function balanceOf(address who) public view returns (uint256) {
        if (deprecated) {
            return UpgradedERC20Token(upgradedAddress).balanceOf(who);
        } else {
            return super.balanceOf(who);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function approve(address _spender, uint256 _value)
        public
        returns (bool sucess)
    {
        if (deprecated) {
            UpgradedERC20Token(upgradedAddress).approveByLegacy(
                msg.sender,
                _spender,
                _value
            );
        } else {
            super.approve(_spender, _value);
        }
        return true;
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function allowance(address _owner, address _spender)
        public
        view
        returns (uint256 remaining)
    {
        if (deprecated) {
            return ERC20Token(upgradedAddress).allowance(_owner, _spender);
        } else {
            return super.allowance(_owner, _spender);
        }
    }

    // deprecate current contract in favour of a new one
    function deprecate(address _upgradedAddress) public onlyOwner {
        deprecated = true;
        upgradedAddress = _upgradedAddress;
        emit Deprecate(_upgradedAddress);
    }

    // deprecate current contract if favour of a new one
    function totalSupply() public view returns (uint256) {
        if (deprecated) {
            return ERC20Token(upgradedAddress).totalSupply();
        } else {
            return tokenTotalSupply;
        }
    }

    // Issue a new amount of tokens
    // these tokens are deposited into the owner address
    //
    // @param _amount Number of tokens to be issued
    function issue(uint256 amount) public onlyOwner {
        require(tokenTotalSupply + amount > tokenTotalSupply);
        require(balances[owner] + amount > balances[owner]);

        balances[owner] += amount;
        tokenTotalSupply += amount;
        emit Issue(amount);
    }

    // Redeem tokens.
    // These tokens are withdrawn from the owner address
    // if the balance must be enough to cover the redeem
    // or the call will fail.
    // @param _amount Number of tokens to be issued
    function redeem(uint256 amount) public onlyOwner {
        require(tokenTotalSupply >= amount);
        require(balances[owner] >= amount);

        tokenTotalSupply -= amount;
        balances[owner] -= amount;
        emit Redeem(amount);
    }

    function setParams(uint256 newBasisPoints, uint256 newMaxFee)
        public
        onlyOwner
    {
        // Ensure transparency by hardcoding limit beyond which fees can never be added
        require(newBasisPoints < 20);
        require(newMaxFee < 50);

        basisPointsRate = newBasisPoints;
        maximumFee = newMaxFee.mul(decimalsfactor);

        emit Params(basisPointsRate, maximumFee);
    }
}

pragma solidity ^0.4.14;

/**
 * Math operations with safety checks
 */
library SafeMath
{
  function mul(uint256 a, uint256 b) pure internal returns (uint256)
  {
    uint256 c = a * b;
    require(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) pure internal returns (uint256)
  {
    // require(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // require(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) pure internal returns (uint256)
  {
    require(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) pure internal returns (uint256)
  {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }

  function max64(uint64 a, uint64 b) pure internal returns (uint64)
  {
    return a >= b ? a : b;
  }

  function min64(uint64 a, uint64 b) pure internal returns (uint64)
  {
    return a < b ? a : b;
  }

  function max256(uint256 a, uint256 b) pure internal returns (uint256)
  {
    return a >= b ? a : b;
  }

  function min256(uint256 a, uint256 b) pure internal returns (uint256)
  {
    return a < b ? a : b;
  }
}

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20Basic
{
  uint256 public totalSupply;
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public;
  event Transfer(address indexed from, address indexed to, uint256 value);
}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic
{
  function allowance(address owner, address spender) public constant returns (uint256);
  function transferFrom(address from, address to, uint256 value) public;
  function approve(address spender, uint256 value) public;
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract StandardToken is ERC20
{
  using SafeMath for uint256;

  mapping(address => uint256) balances;
  mapping(address => mapping (address => uint256)) allowed;

  /**
   * @dev Fix for the ERC20 short address attack.
   */
  modifier onlyPayloadSize(uint256 size)
  {
    require(msg.data.length >= size + 4);
    _;
  }

  /**
   * @dev transfer token for a specified address
   * @param _to The address to transfer to.
   * @param _value The amount to be transferred.
   */
  function transfer(address _to, uint256 _value) public onlyPayloadSize(2 * 32)
  {
    doTransfer(msg.sender, _to, _value);
  }

  function doTransfer(address _from, address _to, uint256 _value) internal
  {
    require(_value > 0);
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(_from, _to, _value);
  }

  /**
   * @dev Gets the balance of the specified address.
   * @param _owner The address to query the the balance of.
   * @return An uint256 representing the amount owned by the passed address.
   */
  function balanceOf(address _owner) public constant returns (uint256 balance)
  {
    return balances[_owner];
  }

  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amout of tokens to be transfered
   */
  function transferFrom(address _from, address _to, uint256 _value) public onlyPayloadSize(3 * 32)
  {
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    doTransfer(_from, _to, _value);
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public onlyPayloadSize(2 * 32)
  {
    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    require((_value == 0) || (allowed[msg.sender][_spender] == 0));
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifing the amount of tokens still avaible for the spender.
   */
  function allowance(address _owner, address _spender) public constant returns (uint256 remaining)
  {
    return allowed[_owner][_spender];
  }
}

/// @title Migration Agent interface
contract MigrationAgent
{
  function migrateFrom(address _from, uint256 _value) public;
}

/**
 * Ownable
 *
 * Base contract with an owner.
 * Provides onlyOwner modifier, which prevents function from running if it is called by anyone other than the owner.
 */
contract Ownable
{
  address public owner;

  function Ownable() public
  {
    owner = msg.sender;
  }

  modifier onlyOwner()
  {
    require(msg.sender == owner);
    _;
  }

  function transferOwnership(address newOwner) public onlyOwner
  {
    if (newOwner != address(0))
    {
      owner = newOwner;
    }
  }
}

/// @title Simple fixed supply token for testing PRIME discounts
contract FixedSupplyToken is StandardToken, Ownable
{
  string public name;
  string public symbol;
  string public version;
  uint256 public decimals = 18;

  /**
   * @dev Contructor
   */
  function FixedSupplyToken(string _name, string _symbol, string _version, uint _decimals, uint _supply) public
  {
    name = _name;
    symbol = _symbol;
    version = _version;
    decimals = _decimals;
    totalSupply = _supply;
    balances[msg.sender] = _supply;
  }
}

/// @title Token class for PrimeStar projects
contract PrimeStarProjectToken is StandardToken, Ownable
{
  event Purchase(address indexed backer, uint eth, uint prime, uint totalTokens, uint discountedTokens);
  event Correction(address indexed backer, uint tokens, bool sub, string reason);
  event FundingFinished(uint collected, uint platformFee);
  event DividendsStarted(uint total);
  event Dividend(address indexed to, uint value);
  event DividendsFinished(uint etherDistributed, uint etherReturned, uint tokensDistributed, uint tokensSkipped);
  event Withdraw(address to, uint value);

  string public name;
  string public symbol;
  string public version;
  uint public decimals;

  address public migrationAgent;
  uint public totalMigrated;

  // Address of the ERC20 (full, must support allowance) PRIME token which acts as a discount
  ERC20 public primeToken;
  uint public primeDecimals;
  uint8 public discountPercent;
  uint8 public platformPercent;
  uint public tokenPrice;
  uint public priceDivisor;

  uint8 public state; // 0 = funding, 1 = funding finished, 2 = distributing dividends (transactions are blocked)

  address public beneficiary;
  uint public pendingDividends;
  uint public pendingTokens;
  uint public initialDividends;

  /**
   * @dev Contructor
   */
  function PrimeStarProjectToken(
    string _name, string _symbol, string _version, uint _decimals, address _beneficiary,
    ERC20 _primeToken, uint _primeDecimals, uint8 _discountPercent, uint8 _platformPercent,
    uint _tokenPrice, uint _priceDivisor) public
  {
    require(_discountPercent > 0 && _discountPercent < 100);
    require(_platformPercent >= 0 && _platformPercent < 100);
    name = _name;
    symbol = _symbol;
    version = _version;
    decimals = _decimals;
    primeToken = _primeToken;
    primeDecimals = _primeDecimals;
    discountPercent = _discountPercent;
    platformPercent = _platformPercent;
    beneficiary = _beneficiary;
    priceDivisor = _priceDivisor;
    tokenPrice = _tokenPrice;
    totalSupply = 0;
  }

  function setDiscount(uint8 _discountPercent) public onlyOwner
  {
    discountPercent = _discountPercent;
  }

  function kill(address _to) public onlyOwner
  {
    selfdestruct(_to);
  }

  function calcCount(uint _prime, uint _eth) public constant
    returns(uint _tokens, uint _bonus)
  {
    _tokens = _eth.mul(priceDivisor).div(tokenPrice);
    _bonus = 0;
    if (_prime > 0)
    {
      // If prime decimals > token decimals, then for example 1000 prime gives discount for 1 token
      uint d = decimals;
      uint pd = primeDecimals;
      if (pd == d)
        _bonus = _prime;
      else if (pd > d)
        _bonus = _prime.div(10 ** (pd-d));
      else
        _bonus = _prime.mul(10 ** (d-pd));
      if (_bonus > _tokens)
        _bonus = _tokens;
    }
    _tokens = _tokens.add(_bonus.mul(discountPercent).div(100));
  }

  function doPurchase() public payable
  {
    // Allow calls only from within the platform. In fact, not really required:
    // if someone wants that hard to buy tokens manually he'll just not get any dividends :)
    //require(tx.origin == owner);
    require(state == 0);
    uint eth;
    uint prime;
    uint tokens;
    uint discounted;
    eth = msg.value;
    prime = primeToken.allowance(msg.sender, this);
    (tokens, discounted) = calcCount(prime, eth);
    if (prime > 0)
    {
      require(primeToken.balanceOf(msg.sender) >= prime);
      primeToken.transferFrom(msg.sender, owner, prime);
    }
    balances[msg.sender] = balances[msg.sender].add(tokens);
    totalSupply = totalSupply.add(tokens);
    Purchase(msg.sender, eth, prime, tokens, discounted);
  }

  function correction(address backer, uint tokens, bool sub, string reason) public onlyOwner
  {
    if (sub)
      balances[msg.sender] = balances[msg.sender].sub(tokens);
    else
      balances[msg.sender] = balances[msg.sender].add(tokens);
    Correction(backer, tokens, sub, reason);
  }

  /**
   * @dev Finish funding
   */
  function finishFunding() public onlyOwner
  {
    require(state == 0);
    uint totalBalance = this.balance;
    uint platformFee = totalBalance.mul(platformPercent).div(100);
    state = 1;
    // Send everything to owner by now
    owner.transfer(totalBalance);
    FundingFinished(totalBalance, platformFee);
  }

  /**
   * @dev Restart funding (for the case of emergency)
   */
  function restartFunding() public onlyOwner
  {
    require(state == 1);
    state = 0;
  }

  /**
   * @dev Put money for dividends
   */
  function startDividends() public payable
  {
    require(state == 1);
    require(msg.sender == owner || msg.sender == beneficiary);
    require(msg.value > 0);
    state = 2;
    pendingDividends = msg.value;
    initialDividends = msg.value;
    pendingTokens = totalSupply;
    DividendsStarted(pendingDividends);
  }

  /**
   * @dev Distribute some dividends in proportion to owned tokens
   * @param backers Backer address to send dividends to
   */
  function sendDividends(address[] backers) public onlyOwner
  {
    require(state == 2);
    uint left = pendingDividends;
    uint tokensLeft = pendingTokens;
    require(left > 0);
    for (uint32 i = 0; i < backers.length; i++)
    {
      uint t = balances[backers[i]];
      if (t > 0)
      {
        uint e = left.mul(t).div(tokensLeft);
        if (e > 0)
        {
          left -= e;
          tokensLeft -= t;
          backers[i].transfer(e);
          Dividend(backers[i], e);
        }
      }
    }
    pendingDividends = left;
    pendingTokens = tokensLeft;
  }

  /**
   * @dev Finish distributing dividends
   */
  function finishDividends(bool _returnToOwner) public onlyOwner
  {
    require(state == 2);
    uint p = pendingDividends;
    uint t = pendingTokens;
    DividendsFinished(initialDividends - p, p, totalSupply - t, t);
    initialDividends = 0;
    pendingDividends = 0;
    pendingTokens = 0;
    state = 1;
    if (_returnToOwner)
      owner.transfer(this.balance);
  }

  /**
   * @dev Withdraw funds
   */
  function withdraw(address _to, uint _value) public onlyOwner
  {
    require(state == 1);
    _to.transfer(_value);
    Withdraw(_to, _value);
  }

  /**
   * @dev Block transactions when distributing dividends
   */
  function doTransfer(address _from, address _to, uint _value) internal
  {
    require(state != 2);
    super.doTransfer(_from, _to, _value);
  }

  /**
   * @dev Set migration agent
   * @param _agent MigrationAgent
   */
  function setMigrationAgent(address _agent) external onlyOwner
  {
    migrationAgent = _agent;
  }

  /**
   * @dev Migrates some tokens to a new version of contract
   * @param _value The number of tokens to migrate
   */
  function migrate(uint _value) external
  {
    // Abort if not in Operational Migration state.
    require(migrationAgent != 0);

    // Validate input value.
    require(_value > 0);
    require(_value <= balances[msg.sender]);

    balances[msg.sender] -= _value;
    totalSupply -= _value;
    totalMigrated += _value;
    MigrationAgent(migrationAgent).migrateFrom(msg.sender, _value);
  }
}

/**
 * Simple system-owned user wallet
 */
contract UserWalletContract is Ownable
{
  event Deposit(address from, uint value);
  event Withdraw(address to, uint value);

  function kill(address _to) public onlyOwner
  {
    selfdestruct(_to);
  }

  function doPurchase(PrimeStarProjectToken _token, uint _eth, uint _prime, uint _tokens) public onlyOwner
  {
    //uint initialGas = msg.gas;
    ERC20 primeToken = _token.primeToken();
    uint initialBalance = _token.balanceOf(this);
    if (_prime > 0)
      primeToken.approve(_token, _prime);
    _token.doPurchase.value(_eth)();
    uint resultingBalance = _token.balanceOf(this);
    require(resultingBalance > initialBalance && resultingBalance-initialBalance == _tokens);
    // FIXME Charge gas price from user wallet
    //msg.sender.transfer((21000 + _initialGas - msg.gas) * tx.gasprice);
  }

  function startDividends(PrimeStarProjectToken _token, uint _value) public onlyOwner
  {
    _token.startDividends.value(_value)();
  }

  function withdraw(address _to, uint _value) public onlyOwner
  {
    _to.transfer(_value);
    Withdraw(_to, _value);
  }

  function withdrawTokens(address _to, ERC20 _token, uint _value) public onlyOwner
  {
    _token.transfer(_to, _value);
  }

  // gets called when no other function matches
  function() public payable
  {
    // just being sent some cash?
    if (msg.value > 0)
    {
      Deposit(msg.sender, msg.value);
    }
  }
}

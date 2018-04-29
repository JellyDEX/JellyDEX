pragma solidity ^0.4.23;

// ----------------------------------------------------------------------------
// library SafeMath
// https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/math/SafeMath.sol
// ----------------------------------------------------------------------------
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
// added a blank def block to totalSupply()
// ----------------------------------------------------------------------------
contract ERC20Interface {
    //function totalSupply() public constant returns (uint);
    function totalSupply() public pure returns (uint256) {}
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    // TODO: might be able to remove this, don't use it anywhere
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint _tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    
    uint256 public decimals;
    string public name;
}

// TODO: remove after testing
contract StandardToken is ERC20Interface {

  function transfer(address _to, uint256 _value) public returns (bool success) {
    //Default assumes totalSupply can't be over max (2^256 - 1).
    //If your token leaves out totalSupply and can issue more tokens as time goes on, you need to check if it doesn't wrap.
    //Replace the if with this one instead.
    if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
    //if (balances[msg.sender] >= _value && _value > 0) {
      balances[msg.sender] -= _value;
      balances[_to] += _value;
      emit Transfer(msg.sender, _to, _value);
      return true;
    } else { return false; }
  }

  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
    //same as above. Replace this line with the following if you want to protect against wrapping uints.
    if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
    //if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
      balances[_to] += _value;
      balances[_from] -= _value;
      allowed[_from][msg.sender] -= _value;
      emit Transfer(_from, _to, _value);
      return true;
    } else { return false; }
  }

  function balanceOf(address _owner) constant public returns (uint256 balance) {
    return balances[_owner];
  }

  function approve(address _spender, uint256 _value) public returns (bool success) {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  function allowance(address _owner, address _spender) constant public returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  mapping(address => uint256) balances;

  mapping (address => mapping (address => uint256)) allowed;

  uint256 public totalSupply;
}


// TODO: remove after testing. This is a simple minting scheme
contract TestingToken is StandardToken {
  address public minter;
  constructor() public {
    minter = msg.sender;
  }
  function create(address account, uint256 amount) public {
    require(msg.sender == minter);
    balances[account] = SafeMath.add(balances[account], amount);
    totalSupply = SafeMath.add(totalSupply, amount);
  }
  function destroy(address account, uint256 amount) public {
    require(msg.sender == minter);
    require(balances[account] >= amount);
    balances[account] = SafeMath.sub(balances[account], amount);
    totalSupply = SafeMath.sub(totalSupply, amount);
  }
}

contract JellyDEX {
  address public admin; //the admin address
  address public feeAccount; //the account that will receive fees
  uint256 public feeTake; //percentage times (1 ether)
  mapping (address => mapping (address => uint256)) public internalTokens; //mapping of token addresses to mapping of account balances. token=0 means eth
  mapping (bytes32 => uint256) public orderFilled; // amount that an order has been filled

  event Order(address tokenGet, uint256 amountGet, address tokenGive, uint256 amountGive, uint256 expires, uint256 nonce, address user);
  event Cancel(address tokenGet, uint256 amountGet, address tokenGive, uint256 amountGive, uint256 expires, uint256 nonce, address user, uint8 v, bytes32 r, bytes32 s);
  event Trade(address tokenGet, uint256 amountGet, address tokenGive, uint256 amountGive, address get, address give);
  event Deposit(address token, address user, uint256 amount);
  event Withdraw(address token, address user, uint256 amount);
  
  // note the feeTake is always divided by 1 ether
  constructor(address admin_, address feeAccount_, uint256 feeTake_) public {
    admin = admin_;
    feeAccount = feeAccount_;
    feeTake = feeTake_;
  } 

  function() public{
    require(false);
  }
  
  // This can be called by the admin to change the admin
  function changeAdmin(address admin_) public {
    require(msg.sender == admin);
    admin = admin_;
  }

  // This can be called by the admin to change the fee account
  function changeFeeAccount(address feeAccount_) public {
    require(msg.sender == admin);
    feeAccount = feeAccount_;
  }
  
  // This can be called by the admin to reduce the make fee. No increases in fees allowed
  function changeFeeTake(uint256 feeTake_) public {
    require(msg.sender == admin);
    require(feeTake > feeTake_);
    feeTake = feeTake_;
  }
  
  // This deposits ether
  function deposit() public payable {
    internalTokens[0][msg.sender] = SafeMath.add(internalTokens[0][msg.sender], msg.value);
    emit Deposit(0, msg.sender, msg.value);
  }

  // This withdraws ether
  function withdraw(uint256 amount) public {
    require(internalTokens[0][msg.sender] >= amount);
    internalTokens[0][msg.sender] = SafeMath.sub(internalTokens[0][msg.sender], amount);
    if (!msg.sender.call.value(amount)()) {
            require(false); // revert changes
    }
    emit Withdraw(0, msg.sender, amount);
  }
  
  // This deposits a token
  function depositToken(address token, uint256 amount) public {
    //remember to call ERC20Interface(address).approve(this, amount)
    require(token != 0);
    require(ERC20Interface(token).transferFrom(msg.sender, this, amount));
    internalTokens[token][msg.sender] = SafeMath.add(internalTokens[token][msg.sender], amount);
    emit Deposit(token, msg.sender, amount);
  }

  // This withdraws a token
  function withdrawToken(address token, uint256 amount) public {
    require(token != 0);
    require(internalTokens[token][msg.sender] >= amount);
    internalTokens[token][msg.sender] = SafeMath.sub(internalTokens[token][msg.sender], amount);
    require(ERC20Interface(token).transfer(msg.sender, amount));
    emit Withdraw(token, msg.sender, amount);
  }

  // This can be called to get the balance of a user's token
  function balanceOf(address token, address user) constant public returns (uint256) {
    return internalTokens[token][user];
  }

  function trade(address tokenGet, uint256 amountGet, address tokenGive, uint256 amountGive, uint256 expires, uint256 nonce, address user, uint8 v, bytes32 r, bytes32 s, uint256 amount) public {
    //amount is in amountGet terms
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce, user);
    require (
      (ecrecover(keccak256("\x19Ethereum Signed Message:\n32", hash),v,r,s) == user) &&
      block.number <= expires &&
      SafeMath.add(orderFilled[hash], amount) <= amountGet
    );
    // calc take fee and move balances around, while using safeMath
    uint256 feeTakeAmount = SafeMath.mul(amount, feeTake) / (1 ether);
    internalTokens[tokenGet][msg.sender] = SafeMath.sub(internalTokens[tokenGet][msg.sender], SafeMath.add(amount, feeTakeAmount));
    internalTokens[tokenGet][user] = SafeMath.add(internalTokens[tokenGet][user], amount);
    internalTokens[tokenGet][feeAccount] = SafeMath.add(internalTokens[tokenGet][feeAccount], feeTakeAmount);
    internalTokens[tokenGive][user] = SafeMath.sub(internalTokens[tokenGive][user], SafeMath.mul(amountGive, amount) / amountGet);
    internalTokens[tokenGive][msg.sender] = SafeMath.add(internalTokens[tokenGive][msg.sender], SafeMath.mul(amountGive, amount) / amountGet);
    // add to order filled
    orderFilled[hash] = SafeMath.add(orderFilled[hash], amount);
    emit Trade(tokenGet, amount, tokenGive, amountGive * amount / amountGet, user, msg.sender);
  }
  
  // This can be called before a trade is broadcast to test a trade's validity
  function testTrade(address tokenGet, uint256 amountGet, address tokenGive, uint256 amountGive, uint256 expires, uint256 nonce, address user, uint8 v, bytes32 r, bytes32 s, uint256 amount, address sender) constant public returns(bool) {
    if (!(
      internalTokens[tokenGet][sender] >= amount &&
      availableVolume(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, user, v, r, s) >= amount
    )) return false;
    return true;
  }
  
  // This determines the available volume of a trade being tested
  function availableVolume(address tokenGet, uint256 amountGet, address tokenGive, uint256 amountGive, uint256 expires, uint256 nonce, address user, uint8 v, bytes32 r, bytes32 s) constant public returns(uint256) {
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce, user);
    if (!(
      (ecrecover(keccak256("\x19Ethereum Signed Message:\n32", hash),v,r,s) == user) &&
      block.number <= expires
    )) return 0;
    uint256 available1 = SafeMath.sub(amountGet, orderFilled[hash]);
    uint256 available2 = SafeMath.mul(internalTokens[tokenGive][user], amountGet) / amountGive;
    if (available1 < available2) return available1;
    return available2;
  }

  // This returns the amount an order has been filled
  function amountFilled(address tokenGet, uint256 amountGet, address tokenGive, uint256 amountGive, uint256 expires, uint256 nonce, address user) constant public returns(uint256) {
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce, user);
    return orderFilled[hash];
  }

  // This cancels an existing order that is resting by making its amount filled full while not changing balances
  // Must be sent by the owner of the order
  function cancelOrder(address tokenGet, uint256 amountGet, address tokenGive, uint256 amountGive, uint256 expires, uint256 nonce, uint8 v, bytes32 r, bytes32 s) public {
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce, msg.sender);
    require(ecrecover(keccak256("\x19Ethereum Signed Message:\n32", hash),v,r,s) == msg.sender);
    orderFilled[hash] = amountGet;
    emit Cancel(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, msg.sender, v, r, s);
  }
}
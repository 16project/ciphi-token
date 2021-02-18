pragma solidity ^0.5.5;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol';

import "../library/Governance.sol";

/// @title CitizenFi Contract

contract CitizenFi is Governance, ERC20Detailed{

    using SafeMath for uint256;

    //events
    event eveSetRate(uint256 burn_rate, uint256 game_rate);
    event eveGamePool(address gamePool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // for baelish
    mapping (address => bool) public _baelish;

    //token base data
    uint256 internal _totalSupply;
    mapping(address => uint256) public _balances;
    mapping (address => mapping (address => uint256)) public _allowances;

    /// Constant token specific fields
    uint256 public  _maxSupply = 0;

    ///
    bool public _openTransfer = false;

    // hardcode limit rate
    uint256 public constant _maxGovernValueRate = 2000;//2000/10000
    uint256 public constant _minGovernValueRate = 10;  //10/10000
    uint256 public constant _rateBase = 10000; 

    // additional variables for use if transaction fees ever became necessary
    uint256 public  _burnRate = 100;       
    uint256 public  _gameRate = 100;   

    uint256 public _totalBurnToken = 0;
    uint256 public _totalGameToken = 0;

    //todo game pool!
    address public _gamePool = 0xE2890165e8685153F7A460472a2247Da922606c9;
    //todo burn pool!
    address public _burnPool = 0x0000000000000000000000000000000000000000;

    /**
    * @dev set the token transfer switch
    */
    function enableOpenTransfer() public onlyGovernance  
    {
        _openTransfer = true;
    }


    /**
     * CONSTRUCTOR
     *
     * @dev Initialize the Token
     */

    constructor () public ERC20Detailed("citizen.Fi", "CIFI", 18) {
         _maxSupply = 500000 * (10**18);
    }


    
    /**
    * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    * @param spender The address which will spend the funds.
    * @param amount The amount of tokens to be spent.
    */
    function approve(address spender, uint256 amount) external 
    returns (bool) 
    {
        require(msg.sender != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);

        return true;
    }

    /**
    * @dev Function to check the amount of tokens than an owner _allowed to a spender.
    * @param owner address The address which owns the funds.
    * @param spender address The address which will spend the funds.
    * @return A uint256 specifying the amount of tokens still available for the spender.
    */
    function allowance(address owner, address spender) external view 
    returns (uint256) 
    {
        return _allowances[owner][spender];
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address owner) external  view 
    returns (uint256) 
    {
        return _balances[owner];
    }

    /**
    * @dev return the token total supply
    */
    function totalSupply() external view 
    returns (uint256) 
    {
        return _totalSupply;
    }

    /**
    * @dev for mint function
    */
    function mint(address account, uint256 amount) external 
    {
        require(account != address(0), "ERC20: mint to the zero address");
        require(_baelish[msg.sender], "!minter");

        uint256 curMintSupply = _totalSupply.add(_totalBurnToken);
        uint256 newMintSupply = curMintSupply.add(amount);
        require( newMintSupply <= _maxSupply,"supply is max!");
      
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);

        emit Mint(address(0), account, amount);
        emit Transfer(address(0), account, amount);
    }

    function addLordBaelish(address _peter) public onlyGovernance 
    {
        _baelish[_peter] = true;
    }
    
    function removeLordBaelish(address _peter) public onlyGovernance 
    {
        _baelish[_peter] = false;
    }
    

    function() external payable {
        revert();
    }

    /**
    * @dev for govern value
    */
    function setRate(uint256 burn_rate, uint256 game_rate) public 
        onlyGovernance 
    {
        
        require(_maxGovernValueRate >= burn_rate && burn_rate >= _minGovernValueRate,"invalid burn rate");
        require(_maxGovernValueRate >= game_rate && game_rate >= _minGovernValueRate,"invalid game rate");

        _burnRate = burn_rate;
        _gameRate = game_rate;

        emit eveSetRate(burn_rate, game_rate);
    }


    /**
    * @dev for set game
    */
    function setGamePool(address gamePool) public 
        onlyGovernance 
    {
        require(gamePool != address(0x0));

        _gamePool = gamePool;

        emit eveGamePool(_gamePool);
    }
    /**
    * @dev transfer token for a specified address
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
   function transfer(address to, uint256 value) external 
   returns (bool)  
   {
        return _transfer(msg.sender,to,value);
    }

    /**
    * @dev Transfer tokens from one address to another
    * @param from address The address which you want to send tokens from
    * @param to address The address which you want to transfer to
    * @param value uint256 the amount of tokens to be transferred
    */
    function transferFrom(address from, address to, uint256 value) external 
    returns (bool) 
    {
        uint256 allow = _allowances[from][msg.sender];
        _allowances[from][msg.sender] = allow.sub(value);
        
        return _transfer(from,to,value);
    }

 

    /**
    * @dev Transfer tokens with fee
    * @param from address The address which you want to send tokens from
    * @param to address The address which you want to transfer to
    * @param value uint256s the amount of tokens to be transferred
    */
    function _transfer(address from, address to, uint256 value) internal 
    returns (bool) 
    {
        // :)
        require(_openTransfer || from == governance, "transfer closed");

        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 sendAmount = value;
        uint256 burnFee = (value.mul(_burnRate)).div(_rateBase);
        if (burnFee > 0) {
            //to burn
            _balances[_burnPool] = _balances[_burnPool].add(burnFee);
            _totalSupply = _totalSupply.sub(burnFee);
            sendAmount = sendAmount.sub(burnFee);

            _totalBurnToken = _totalBurnToken.add(burnFee);

            emit Transfer(from, _burnPool, burnFee);
        }

        uint256 gameFee = (value.mul(_gameRate)).div(_rateBase);
        if (gameFee > 0) {
           //to game
            _balances[_gamePool] = _balances[_gamePool].add(gameFee);
            sendAmount = sendAmount.sub(gameFee);

            _totalGameToken = _totalGameToken.add(gameFee);

            emit Transfer(from, _gamePool, gameFee);
        }

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(sendAmount);

        emit Transfer(from, to, sendAmount);

        return true;
    }
}
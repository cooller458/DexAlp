pragma solidity 0.8.7;

import "./Token.sol";
import "./Ilighthouse.sol"; 
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DexAlp is Ownable {
    using SafeMath for uint;
    ILighthouse  public myLighthouse;

    bool public emergency;

    modifier stopInEmergency { 
        require(!emergency); 
        _; 
    }

    modifier onlyInEmergency { 
        require(emergency); 
        _;
    }
    address public feeAccount; 
    uint256 public feePercent; 
    
    address public constant ETHER = address(0;
    mapping(address => mapping(address => uint256)) public tokens;
    
    mapping(uint256 => _Order) public orders;
    uint256 public orderCount;
    uint256 public cancelledOrderCount;
    uint256 public filledOrderCount;
    
    
    mapping(uint256 => bool) public orderCancelled;
    mapping(uint256 => bool) public orderFilled;
    
    
    bool private locked = false;

    
    event Deposit(address token, address user, uint256 amount, uint256 balance);
    event Withdraw(address token, address user, uint256 amount, uint256 balance);
    event Order(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );
    
    event Cancel(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );
    event Trade(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        address userFill,
        uint256 timestamp, 
        bool isLucky
    ); 
    event StopExchange(address admin, bool isEmergency); 
    event StartExchange(address admin, bool isEmergency); 
    struct _Order {
        uint256 id;
        address user;
        address tokenGet;
        uint256 amountGet;
        address tokenGive;
        uint256 amountGive;
        uint256 timestamp;
    }
    constructor (address _feeAccount, uint256 _feePercent, ILighthouse _myLighthouse) public {
        feeAccount = _feeAccount;
        feePercent = _feePercent;
        myLighthouse = _myLighthouse;
        admin = msg.sender;
    } 
    function stopExchange() external onlyOwner stopInEmergency {
        emergency = true;
        emit StopExchange(msg.sender, emergency);
    }
    function startExchange() external onlyOwner onlyInEmergency {
        emergency = false;
        emit StartExchange(msg.sender, emergency);
    }
    function() external {
        revert();
    }   
    function depositEther() payable external stopInEmergency {
        tokens[ETHER][msg.sender] = tokens[ETHER][msg.sender].add(msg.value);
        emit Deposit(ETHER, msg.sender, msg.value, tokens[ETHER][msg.sender]);
    } 
    function withdrawEther(uint _amount) external {
        require(tokens[ETHER][msg.sender] >= _amount);
        require(!locked, "Reentrant call detected!
        tokens[ETHER][msg.sender] = tokens[ETHER][msg.sender].sub(_amount);
        require(msg.sender.call.value(_amount)(""));
        emit Withdraw(ETHER, msg.sender, _amount, tokens[ETHER][msg.sender]);
        locked = false;
    }
    function depositToken(address _token, uint _amount) stopInEmergency external {
        require(_token != ETHER);
        require(Token(_token).transferFrom(msg.sender, address(this), _amount));
        tokens[_token][msg.sender] = tokens[_token][msg.sender].add(_amount);
        emit Deposit(_token, msg.sender, _amount, tokens[_token][msg.sender]);
    }
    function withdrawToken(address _token, uint256 _amount) external {
        require(_token != ETHER);
        require(tokens[_token][msg.sender] >= _amount);
        tokens[_token][msg.sender] = tokens[_token][msg.sender].sub(_amount);
        require(Token(_token).transfer(msg.sender, _amount));
        emit Withdraw(_token, msg.sender, _amount, tokens[_token][msg.sender]);
    }
    

    function balanceOf(address _token, address _user) external view returns (uint256) {
        return tokens[_token][_user];
    }
 
    function makeOrder(address _tokenGet, uint256 _amountGet, address _tokenGive, uint256 _amountGive) external stopInEmergency {
        orderCount = orderCount.add(1);
        orders[orderCount] = _Order(orderCount, msg.sender, _tokenGet, _amountGet, _tokenGive, _amountGive, now);
        emit Order(orderCount, msg.sender, _tokenGet, _amountGet, _tokenGive, _amountGive, now);
    }
 
    function cancelOrder(uint256 _id) external {
        _Order storage _order = orders[_id];
        require(address(_order.user) == msg.sender);
        require(_order.id == _id); 
        cancelledOrderCount = cancelledOrderCount.add(1);
        orderCancelled[_id] = true;
        emit Cancel(_order.id, msg.sender, _order.tokenGet, _order.amountGet, _order.tokenGive, _order.amountGive, now);
    }
  
    function fillOrder(uint256 _id) external stopInEmergency {
        require(_id > 0 && _id <= orderCount);
        require(!orderFilled[_id]);
        require(!orderCancelled[_id]);
        _Order storage _order = orders[_id];
        _trade(_order.id, _order.user, _order.tokenGet, _order.amountGet, _order.tokenGive, _order.amountGive);
        filledOrderCount = filledOrderCount.add(1);
        orderFilled[_order.id] = true;
    
    } 
    function _trade(uint256 _orderId, address _user, address _tokenGet, uint256 _amountGet, address _tokenGive, uint256 _amountGive) internal {         

        bool _isLucky =  _rollDiceLucky();
        if(!_isLucky) {
            uint256 _feeAmount = _amountGet.mul(feePercent).div(100);        
            tokens[_tokenGet][msg.sender] = tokens[_tokenGet][msg.sender].sub(_amountGet.add(_feeAmount));
            tokens[_tokenGet][_user] = tokens[_tokenGet][_user].add(_amountGet);
            tokens[_tokenGet][feeAccount] = tokens[_tokenGet][feeAccount].add(_feeAmount);
            tokens[_tokenGive][_user] = tokens[_tokenGive][_user].sub(_amountGive);
            tokens[_tokenGive][msg.sender] = tokens[_tokenGive][msg.sender].add(_amountGive);
       
        } else {
            uint256 _feeAmount = 0;        
            tokens[_tokenGet][msg.sender] = tokens[_tokenGet][msg.sender].sub(_amountGet.add(_feeAmount));
            tokens[_tokenGet][_user] = tokens[_tokenGet][_user].add(_amountGet);
            tokens[_tokenGive][_user] = tokens[_tokenGive][_user].sub(_amountGive);
            tokens[_tokenGive][msg.sender] = tokens[_tokenGive][msg.sender].add(_amountGive);
        }

        emit Trade(_orderId, _user, _tokenGet, _amountGet, _tokenGive, _amountGive, msg.sender, now, _isLucky);  
    }
    

import "token.sol";
import "Owned.sol";



contract SimpleExchange is Owned {
    uint public nextOrderId = 1; // Identifies an order
    event OrderConfirmationEvent(uint orderId, address seller, address buyer, uint256 volume);
    struct SellOrder {
        uint256 volume;
        uint256 unitPrice;
        Token token;
        TokenRegistry registry; // Optional
        address seller;
    }
    mapping (uint => SellOrder) public sellOrderMap; // Map from order id

    // The following data structures are only used for exporting orders

    uint[] public openOrderList;
    mapping (uint => uint) public indexMap;

    modifier zeroFunding {
        if (msg.value != 0) throw;
        _
    }

    function SimpleExchange() {
    }

    function removeSellOrder(uint orderId) internal {
        // Remove the order itself
        SellOrder sellorder = sellOrderMap[orderId];
        delete sellOrderMap[orderId];

        // Find the index in the order list, and remove it
        uint i = indexMap[orderId];
        openOrderList[i] = openOrderList[openOrderList.length-1];
        openOrderList.length--;
        indexMap[openOrderList[i]] = i; // This order was moved to index 'i'
        delete indexMap[orderId]; // Remove the map entry for the deleted order

    }

    // Negative return value means there is an error.
    function createOffer(uint256 _volume, uint256 _unitPrice, Token _token, TokenRegistry _registry) zeroFunding returns (int) {
        if (_volume == 0) return -1;
        if (_token.balanceOf(msg.sender) < _volume) return -2;
        if (_token.allowance(msg.sender, this) < _volume) return -3;
        if (!_token.transferFrom(msg.sender, this, _volume)) return -4;
        uint orderId = nextOrderId++;
        sellOrderMap[orderId] = SellOrder(_volume, _unitPrice, _token, _registry, msg.sender); // If there was an old offer, it is replaced

        uint i = openOrderList.push(orderId);
        indexMap[orderId] = i;

        return int(orderId);
    }

    // Allow partial buys. Price must match exactly, or something has changed.
    function buy(uint orderId, uint256 _volume, uint256 _unitPrice) {
        SellOrder sellorder = sellOrderMap[orderId];
        if (sellorder.volume == 0) throw; // There was no transaction
        if (sellorder.unitPrice != _unitPrice) throw;
        if (sellorder.volume < _volume) throw;
        uint totalPrice = _unitPrice * _volume;
        if (msg.value != totalPrice) throw;
        Token token = sellorder.token;
        address seller = sellorder.seller;
        if (!token.transfer(msg.sender, _volume)) throw;
        seller.send(msg.value);
        sellorder.volume -= _volume;
        if (sellorder.volume == 0)
            removeSellOrder(orderId);
        OrderConfirmationEvent(orderId, seller, msg.sender, _volume);
    }

    function cancelSellOrder(uint orderId) zeroFunding {
        SellOrder sellorder = sellOrderMap[orderId];
        Token token = sellorder.token;
        if (token == Token(0)) throw;
        if (msg.sender != sellorder.seller || msg.sender != owner) throw;
        // Return the tokens
        if (!token.transfer(sellorder.seller, sellorder.volume)) throw;
        removeSellOrder(orderId);
    }

    /* This unnamed function is called whenever someone tries to send ether to it */
    function () {
        throw;     // Prevents accidental sending of ether
    }

    function destruct() onlyOwner {
        if (openOrderList.length > 0) throw;
        selfdestruct(owner);
    }
}

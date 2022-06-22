//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@elasticswap/elasticswap/src/contracts/Exchange.sol";
import "@elasticswap/elasticswap/src/contracts/ExchangeFactory.sol";

contract AutoBalancer is Ownable {
    using SafeERC20 for IERC20;

    address public exchangeFactory;

    constructor(address _exchangeFactory) {
        exchangeFactory = _exchangeFactory;
    }

    function balanceExchange(address _exchange, uint256 _expirationTimestamp)
        external
        onlyOwner
    {
        // TODO need sane minimums for slippage issues
        require(
            ExchangeFactory(exchangeFactory).isValidExchangeAddress(_exchange),
            "INVALID_EXCHANGE"
        );
        Exchange exchange = Exchange(_exchange);
        // 1. determine imbalance amount
        uint256 baseTokenImbalanceQty = 0; // todo!;
        // 2. pull base token from caller
        IERC20 baseToken = IERC20(exchange.baseToken());
        IERC20 quoteToken = IERC20(exchange.quoteToken());
        baseToken.safeTransferFrom(
            msg.sender,
            address(this),
            baseTokenImbalanceQty
        );
        // 3. add liquidity
        exchange.addLiquidity(
            baseTokenImbalanceQty,
            0, // _quoteTokenQtyDesired
            baseTokenImbalanceQty - 1,
            0, // _quoteTokenQtyMin
            address(this),
            _expirationTimestamp
        );
        // 4. remove liquidity (yielding both base and quote tokens)
        // TODO: do we need a min quote tokens we get back here for slippage?
        exchange.removeLiquidity(
            exchange.balanceOf(address(this)),
            0, // _baseTokenQtyMin,
            0, // _quoteTokenQtyMin,
            address(this),
            _expirationTimestamp
        );
        // 5. swap quote tokens for base tokens
        exchange.swapQuoteTokenForBaseToken(
            quoteToken.balanceOf(address(this)),
            0, // _minBaseTokenQty, //TODO: fix
            _expirationTimestamp
        );
        // 6. return base tokens to caller
        baseToken.transfer(msg.sender, baseToken.balanceOf(address(this)));
    }
}

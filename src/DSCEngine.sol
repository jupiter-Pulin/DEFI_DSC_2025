// SPDX-License-Identifier: MIT
// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;
import {DecentralizedStableCoin} from "./DecentalizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./libraries/OracleLib.sol";

/*
 * @title DSCEngine
 * @author Pu Lin
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
contract DSCEngine is ReentrancyGuard {
    ///////////////////
    // Error
    ///////////////////
    error DSCEngine__moreThanZero();
    error DSCEngine__lengthOfTokenAndPriveFeedsShouldEqual();
    error DSCEngine__NotAllowedTokenAddr();
    error DSCEngine__TransferfromIsfailed();
    error DSCEngine__HealthFactoryIsLessThan1();
    error DSCEngine__HealthFactoryIsOK(uint256);
    error DSCEngine__HealthFactoryIsNotImproved();
    error DSCEngine__mintedFailed();

    ///////////////////
    // Type declarations
    ///////////////////
    using OracleLib for AggregatorV3Interface;
    DecentralizedStableCoin private immutable i_Dsc;

    ///////////////////
    // state variable
    ///////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant DEPOSITE_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS_THRESHOLD = 10;
    uint256 private constant MIN_HEALTH_FACTORY = 1e18; //因为要算上 当前eth/usd价格 我在mock里写的是4000，所以要整的21次方

    mapping(address token => address priceFeeds) private s_priceFeedsMap; //每一个代币的地址都代表了一个该代币地址的datefeeds功能 如：btc/usd  eth/usd 的地址
    mapping(address user => mapping(address collateralToken => uint256 amount))
        private s_collateralDepositedMap;
    mapping(address user => uint256 amount) private s_mintDscMap;
    address[] private s_tokenAddrArray;

    ///////////////////
    // Events
    ///////////////////
    event CollateralizedDeposit(
        address indexed user,
        address indexed tokenCollateralAddr,
        uint256 indexed _amount
    );
    event MintedDSC(uint256 mintAmount);
    event CollateralizedReddem(
        address indexed tokenCollateralAddr,
        uint256 amountCollateral,
        address indexed tokenAddrFrom,
        address indexed tokenAddrTo
    );

    ///////////////////
    // Modifiers
    ///////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__moreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address tokenCollateralAddress) {
        if (s_priceFeedsMap[tokenCollateralAddress] == address(0)) {
            revert DSCEngine__NotAllowedTokenAddr();
        }
        _;
    }

    ///////////////////
    // constructor
    ///////////////////
    constructor(
        address[] memory tokenAddr,
        address[] memory priceFeedsAddr,
        address dscAddr
    ) {
        if (tokenAddr.length != priceFeedsAddr.length) {
            revert DSCEngine__lengthOfTokenAndPriveFeedsShouldEqual();
        }
        for (uint256 i = 0; i < tokenAddr.length; i++) {
            s_priceFeedsMap[tokenAddr[i]] = priceFeedsAddr[i]; //每一个代币的地址都代表了一个该代币地址的datefeeds功能 如：btc/usd  eth/usd 的地址
            s_tokenAddrArray.push(tokenAddr[i]);
        }
        i_Dsc = DecentralizedStableCoin(dscAddr);
    }

    //////////////////////////////////////////////////////
    //                  external function               //
    //////////////////////////////////////////////////////

    /**
     *
     * @param tokenCollateralAddress 这是质押的合约地址，如ERC20;
     * @param amountCollateral 这是你质押代币的数量
     * @param amountToMintDsc 这是你想要换成的DSC代币数量
     */
    function depositCollateralizedAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountToMintDsc
    ) external {
        depositCollateralized(tokenCollateralAddress, amountCollateral);
        mintDSC(amountToMintDsc);
    }

    function redeemCollateralizedAndBurnDSC(
        uint256 amountToBurnDsc,
        address tokenCollateralAddr,
        uint256 amountCollateral
    ) external {
        _burnDsc(amountToBurnDsc, msg.sender, msg.sender);
        _redeemCollateralized(
            tokenCollateralAddr,
            amountCollateral,
            msg.sender,
            msg.sender
        );

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
         *@notice
         *  用户的仓位情况：
    抵押物： 用户抵押了 1 ETH
    当时的 ETH/USD 价格： $4,000
    抵押物的美元价值： $4,000 ($1 \text{ ETH} \times \\$4,000/\text{ETH}$)
    债务： 用户铸造了 2,000 DSC（相当于 $2,000 的债务）
    初始抵押率： $\$4,000 / $2,000 = 200%$
    市场价格下跌：
    新的 ETH/USD 价格： $3,000
    抵押物的新美元价值： $3,000 ($1 \text{ ETH} \times \\$3,000/\text{ETH}$)
    新的抵押率： $\$3,000 / $2,000 = 150%$
    假设系统的 最低抵押率（Minimum Collateralization Ratio） 要求是 160%，那么用户的仓位现在只有 150%，低于最低要求，因此需要被清算。

    清算过程：
    作为清算者，您决定替用户偿还他的债务，并获得相应的抵押物作为补偿。

    偿还用户的债务： 您支付了 2,000 DSC，相当于 $2,000 的债务。

    抵押物的转移： 系统将从用户的抵押物中扣除 0.7334 ETH，并转移到您的账户。

    更新用户的仓位：

    用户的债务减少： $2,000（债务清零）
    用户的抵押物减少： 1 ETH - 0.7334 ETH = 0.2666 ETH（剩余抵押物）
    总结：
    作为清算者，您支付了 2,000 DSC，用于清偿用户的债务。
    您获得了 0.6667 ETH 的抵押物（对应于偿还的债务），以及额外的 0.0667 ETH 的奖励，总计 0.7334 ETH。
    这个过程确保了您所支付的债务与收到的抵押物价值相匹配，并提供了额外的奖励以激励清算者参与。
    为什么要按美元价值计算？
    正如之前所解释的，在清算过程中，我们需要确保：
    公平性： 清算者获得的抵押物应与所偿还的债务等值（加上奖励）。
    系统稳定性： 按照当前的市场价格计算，可以准确反映抵押物和债务的实际价值，防止系统出现资金缺口或多付问题。
    激励机制： 通过提供奖励，激励清算者积极参与清算，维护系统的健康运行。
        */
    function liquidate(
        address user,
        address tokenCollateralizedAddr,
        uint256 debtDsc
    ) external moreThanZero(debtDsc) isAllowedToken(tokenCollateralizedAddr) {
        uint256 startHealthFactory = _healthFactory(user);
        if (startHealthFactory > MIN_HEALTH_FACTORY) {
            revert DSCEngine__HealthFactoryIsOK(startHealthFactory);
        }
        uint256 userDebtFromDSC = getDebtForEthAmount(
            tokenCollateralizedAddr,
            debtDsc
        );
        uint256 bonus = (userDebtFromDSC * LIQUIDATION_BONUS_THRESHOLD) /
            LIQUIDATION_PRECISION;
        uint256 liquidateReward = userDebtFromDSC + bonus;

        _redeemCollateralized(
            tokenCollateralizedAddr,
            liquidateReward,
            user,
            msg.sender
        );
        _burnDsc(debtDsc, user, msg.sender);
        uint256 endHeatlthFactory = _healthFactory(user);

        if (endHeatlthFactory <= startHealthFactory) {
            revert DSCEngine__HealthFactoryIsNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    //////////////////////////////////////////////////////
    //                  public function                 //
    //////////////////////////////////////////////////////
    /** 
    @notice 
     *  nonReentrant 是继承openzeep 的一个防止重入攻击的函数
     * 并且这个tokenCollateralAddress并不是一个账户地址；
     * 而是一个符合ERC20标准的合约地址，用户此前已经将WBTC或WETH放到了此地址，并在之前在前端approve
     * 允许我们的合约调用它的地址的WBTC & WETH
     * 而IERC20的存在意义是定义一个接口，只允许EVM调用tokenCollateralAddress中IERC20定义的函数。
     */
    function depositCollateralized(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDepositedMap[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;
        emit CollateralizedDeposit(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );
        bool sucess = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amountCollateral
        );
        if (!sucess) {
            revert DSCEngine__TransferfromIsfailed();
        }
    }

    /**
         @notice 
         *1.检查mint不允许有超过实际的质押数量，会revert。而revert需要有个 healthFactory 值，检测超过就不予mint
          2.而阈值 则需要有完整的 totalMintDsc 和此user 下的 totalCollateralizedValue
             而质押的value 里面包括了user在ERC20地址中不同的质押账户，需要完整的计算：
             Health Factor = (Total Collateral Value * Weighted Average Liquidation Threshold) / Total Borrow Value
               并且在每个账户中需要引入datafeeds去计算单个的美元价值
                 而datefeeds是以8为小数点计价，所以需要乘10个0.
          3.把一切都搞完以后，因为solidity没有小数点，所以healthFactory需要在算一个精度数学，保证结果只有在大于1的时候才可以去质押
         */
    function mintDSC(
        uint256 amountToMintDsc
    ) public moreThanZero(amountToMintDsc) nonReentrant {
        s_mintDscMap[msg.sender] += amountToMintDsc;

        _revertIfHealthFactorIsBroken(msg.sender);
        emit MintedDSC(amountToMintDsc);

        bool minted = i_Dsc.mint(msg.sender, amountToMintDsc);
        if (!minted) {
            revert DSCEngine__mintedFailed();
        }
    }

    /**
     * @notice 新版本solidity自动检测账户是否有足够的amountCollateral去赎回
     *         1.质押账户的mapping需要清除
     *         2.要给原质押地址转钱
     *         3.最重要的是需要检查健康因子{
     *                                   我们希望质押200$ETH，在50%阈值下 至多领100$DSC
     *                                    但希望赎回的时候满足原质押物品价值不低于 150$
     *                                      目前没有实现，让我们还是以200$赎回   }
     */

    function redeemCollateralized(
        address tokenCollateralAddr,
        uint256 amountCollateral
    ) public moreThanZero(amountCollateral) {
        _redeemCollateralized(
            tokenCollateralAddr,
            amountCollateral,
            msg.sender,
            msg.sender
        );
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc(
        uint256 amountToBurnDsc
    ) public moreThanZero(amountToBurnDsc) {
        _burnDsc(amountToBurnDsc, msg.sender, msg.sender);
    }

    //////////////////////////////////////////////////////
    //             private function                 //////
    //////////////////////////////////////////////////////
    function _burnDsc(
        uint256 amountToBurnDsc,
        address from,
        address to
    ) private {
        s_mintDscMap[from] -= amountToBurnDsc;

        bool success = i_Dsc.transferFrom(to, address(this), amountToBurnDsc);
        if (!success) {
            revert DSCEngine__TransferfromIsfailed();
        }

        i_Dsc.burn(amountToBurnDsc); //因为已经transfer，从user转到dsce中了，所以调用burn合约时，msg.sender其实是dsce合约。
        //transfer以后，被转出的地址余额一定是减少的。
    }

    function _redeemCollateralized(
        address tokenCollateralAddr,
        uint256 amountCollateral,
        address from,
        address to
    ) private nonReentrant {
        s_collateralDepositedMap[from][tokenCollateralAddr] -= amountCollateral;
        emit CollateralizedReddem(
            tokenCollateralAddr,
            amountCollateral,
            from,
            to
        );
        bool success = IERC20(tokenCollateralAddr).transfer(
            to,
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__TransferfromIsfailed();
        }
    }

    //////////////////////////////////////////////////////
    //            private && internal view function     //
    //////////////////////////////////////////////////////
    /**
     * @notice
     * 这里之所以不用amount 算总数，而是在datefeeds里面挨个加每一个地址的钱是因为用户不一定会只是用ETH，如果是WBTC那么就需要不一样的chainlink地址
     */
    function _getCollateralizedValue(
        address user
    ) internal view returns (uint256 totalCollateralValue) {
        for (uint256 i = 0; i < s_tokenAddrArray.length; i++) {
            address token = s_tokenAddrArray[i];
            uint256 amount = s_collateralDepositedMap[user][token];
            totalCollateralValue += getTokenToUsdPrice(token, amount);
        }
        return totalCollateralValue;
    }

    function _getInformation(
        address user
    )
        internal
        view
        returns (uint256 totalDscValue, uint256 totalCollateralValue)
    {
        totalDscValue = s_mintDscMap[user];
        totalCollateralValue = _getCollateralizedValue(user);
    }

    /**
     *
     * @notice  乘以 PRECISION 的原因是因为adjusttotalCollateralValue是正常的计价
     *       如3700$ ,而totalDscValue则是 以1e18为单位去写的。且solidity无法计算小数，如：1.333 => 1
     *  Health Factor = (Total Collateral Value * Weighted Average Liquidation Threshold) / Total Borrow Value
     */
    function _healthFactory(address user) internal view returns (uint256) {
        (uint256 totalDscValue, uint256 totalCollateralValue) = _getInformation(
            user
        );
        return _calculateHealthFactory(totalDscValue, totalCollateralValue);
    }

    function _calculateHealthFactory(
        uint256 totalDscValue,
        uint256 totalCollateralValue
    ) internal pure returns (uint256) {
        if (totalDscValue == 0) return type(uint256).max;
        uint256 adjusttotalCollateralValue = (totalCollateralValue *
            DEPOSITE_THRESHOLD) / LIQUIDATION_PRECISION;

        return (adjusttotalCollateralValue * PRECISION) / totalDscValue;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthyFactory = _healthFactory(user);
        if (userHealthyFactory <= MIN_HEALTH_FACTORY) {
            revert DSCEngine__HealthFactoryIsLessThan1();
        }
    }

    //////////////////////////////////////////////////////
    //  External & Public View & Pure Functions         //
    //////////////////////////////////////////////////////

    function getcollateralDeposited(
        address token,
        address user
    ) public view returns (uint256) {
        return s_collateralDepositedMap[user][token];
    }

    function getAccountInformation(
        address user
    )
        public
        view
        returns (uint256 totalDscValue, uint256 totalCollateralValue)
    {
        (totalDscValue, totalCollateralValue) = _getInformation(user);
    }

    function getDebtForEthAmount(
        address tokenAddr,
        uint256 debtAmount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeeds = AggregatorV3Interface(
            s_priceFeedsMap[tokenAddr]
        );
        (, int256 price, , , ) = priceFeeds.staleCheckLatestRoundData();
        //3000$e18*e18/4000$e8*e10==0.75e18;
        return
            (debtAmount * PRECISION) /
            (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getTokenToUsdPrice(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeeds = AggregatorV3Interface(
            s_priceFeedsMap[token]
        ); //因为s_priceFeedsMap[token]能找到对应 chainlink在该链上的dateFeeds 地址。
        (, int256 price, , , ) = priceFeeds.staleCheckLatestRoundData();
        return
            ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getCalculateHealthFactory(
        uint256 totalDscValue,
        uint256 totalCollateralValue
    ) public pure returns (uint256) {
        return _calculateHealthFactory(totalDscValue, totalCollateralValue);
    }

    //getCalculateHealthFactory 和 getHealthFactoryState 是一样的工作
    function getHealthFactoryState(address user) public view returns (uint256) {
        return _healthFactory(user);
    }

    function getUserMintedDSC(address user) public view returns (uint256) {
        return s_mintDscMap[user];
    }

    function getliquidateReward(
        address tokenCollateralizedAddr,
        uint256 debtDsc
    ) public view returns (uint256) {
        uint256 userDebtFromDSC = getDebtForEthAmount(
            tokenCollateralizedAddr,
            debtDsc
        );
        uint256 bonus = (userDebtFromDSC * LIQUIDATION_BONUS_THRESHOLD) /
            LIQUIDATION_PRECISION;
        uint256 liquidateReward = userDebtFromDSC + bonus;
        return liquidateReward;
    }

    function getCollateralTokenAddr() external view returns (address[] memory) {
        return s_tokenAddrArray;
    }

    function getCollateralTokenPriceFeed(
        address tokenCollateralAddr
    ) public view returns (address) {
        return s_priceFeedsMap[tokenCollateralAddr];
    }

    //////////////////////////////
    /// get Constant view function/////
    //////////////////////////////
    function getPeission() public pure returns (uint256) {
        return PRECISION;
    }

    function getDepositeThreshold() public pure returns (uint256) {
        return DEPOSITE_THRESHOLD;
    }

    function getLiquidatePeission() public pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getAdditionalFeedPeission() public pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidateBonusThreshold() public pure returns (uint256) {
        return LIQUIDATION_BONUS_THRESHOLD;
    }

    function getMinHealthFactory() public pure returns (uint256) {
        return MIN_HEALTH_FACTORY;
    }
}

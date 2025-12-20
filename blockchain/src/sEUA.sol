// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OracleLib, AggregatorV3Interface} from "./libraries/OracleLib.sol";

contract sEUA is ERC20 {
    using OracleLib for AggregatorV3Interface;

    error sEUA_feeds__InsufficientCollateral();

    uint256 private s_euaPrice;
    address private i_ethUsdFeed;

    uint256 public constant DECIMALS = 8;
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address user => uint256 euaMinted) public s_euaMintedPerUser;
    mapping(address user => uint256 ethCollateral) public s_ethCollateralPerUser;

    constructor(address ethUsdFeed) ERC20("Synthetic EUA", "sEUA") {
        i_ethUsdFeed = ethUsdFeed;
    }

    function updateEuaPrice(uint256 newPrice) external {
        s_euaPrice = newPrice;
    }

    function depositAndmint(uint256 amountToMint) external payable {
        s_ethCollateralPerUser[msg.sender] += msg.value;
        s_euaMintedPerUser[msg.sender] += amountToMint;
        uint256 healthFactor = getHealthFactor(msg.sender);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert sEUA_feeds__InsufficientCollateral();
        }
        _mint(msg.sender, amountToMint);
    }

    function redeemAndBurn(uint256 amountToRedeem) external {
        uint256 valueRedeemed = getUsdAmountFromEua(amountToRedeem);
        uint256 ethToReturn = getEthAmountFromUsd(valueRedeemed);
        s_euaMintedPerUser[msg.sender] -= amountToRedeem;
        s_ethCollateralPerUser[msg.sender] -= ethToReturn;
        uint256 healthFactor = getHealthFactor(msg.sender);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert sEUA_feeds__InsufficientCollateral();
        }
        _burn(msg.sender, amountToRedeem);

        (bool success,) = msg.sender.call{value: ethToReturn}("");
        if (!success) {
            revert("sEUA_feeds: transfer failed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getHealthFactor(address user) public view returns (uint256) {
        (uint256 totalEuaMintedValueInUsd, uint256 totalCollateralEthValueInUsd) = getAccountInformationValue(user);
        return _calculateHealthFactor(totalEuaMintedValueInUsd, totalCollateralEthValueInUsd);
    }

    // Now uses the s_euaPrice variable instead of a Chainlink feed
    function getUsdAmountFromEua(uint256 amountEuaInWei) public view returns (uint256) {
        return (amountEuaInWei * (s_euaPrice * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }

    function getUsdAmountFromEth(uint256 ethAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_ethUsdFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return (ethAmountInWei * (uint256(price) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }

    function getEthAmountFromUsd(uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_ethUsdFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return (usdAmountInWei * PRECISION) / ((uint256(price) * ADDITIONAL_FEED_PRECISION) * PRECISION);
    }

    function getAccountInformationValue(address user)
        public
        view
        returns (uint256 totalEuaMintedValueUsd, uint256 totalCollateralValueUsd)
    {
        (uint256 totalEuaMinted, uint256 totalCollateralEth) = _getAccountInformation(user);
        totalEuaMintedValueUsd = getUsdAmountFromEua(totalEuaMinted);
        totalCollateralValueUsd = getUsdAmountFromEth(totalCollateralEth);
    }

    function _calculateHealthFactor(uint256 euaMintedValueUsd, uint256 collateralValueUsd)
        internal
        pure
        returns (uint256)
    {
        if (euaMintedValueUsd == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / euaMintedValueUsd;
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalEuaMinted, uint256 totalCollateralEth)
    {
        totalEuaMinted = s_euaMintedPerUser[user];
        totalCollateralEth = s_ethCollateralPerUser[user];
    }
}

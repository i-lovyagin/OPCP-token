pragma solidity ^0.5.4;

/**
 * @title Operating Capital Pool token sale
 * @author Igor Lovyagin @i-lovyagin
*/

import "./OPCPToken.sol";
// using library from the open-zeppelin project https://github.com/OpenZeppelin/openzeppelin-solidity
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract OPCPTokenSale {
	using SafeMath for uint256;

// instance of the token contract
	OPCPToken public token;
// address to store funds raised at the first stage of the contract lifecycle
// funds to be used for R&D and marketing
	address payable public wallet;
//  running total of raised weis
  	uint256 public weiRaised = 0;
// future use: buying back tokens flag
	bool public refundActive = false;

// flag indicates the first stage of the contract life cycle. No real operations yet and service providers aren't able to register	
	bool public bootstrapMode = true;

// amount of financing used in R&D and marketing
	uint256 public financingGoal;

/**
* Token purchase. 
* @param purchaser address of the payer
* @param beneficiary address of the purchase tokens holder
* @param value amount of transaction in Wei
* @param amount number of tokens
*/
	event TokenPurchase( address indexed purchaser, address indexed beneficiary, uint256 value,	uint256 amount);

/**
* @notice reserved for future use. Need to define a buyback strategy first
* Token refund (buying back tokens) 
* @param holder address of the token holder
* @param price token price 
* @param tokens number of tokens
* @param refund amount of transaction in Wei
*/
	event TokenRefund(address indexed holder, uint256 price, uint256 tokens, uint256 refund);


  constructor(address payable _wallet, OPCPToken _token, uint256 _initFunding, uint8 _ownerPct)  public  {

		wallet = _wallet;
		token = _token;
		financingGoal = token.toWei(token.toUnits(_initFunding));
		token.setStore(_ownerPct);

	}

	/**
	* @dev Fallback function. Receives a payment in Wei and sells tokens if possible
	*/
	function () external payable {
		buyTokens();
	}

	/**
	* @dev Function that reports a number of tokens available for sale
	* @return number of tokens
	*/
	function forSale() public view returns(uint256 tokensForSale)	{
		return token.balanceOfAdj(address(this));
	}

	/**
	* @notice reserved for future use. Need to define a buyback strategy first
	* @dev Function that sets a flag to start refunding tokens
	*/
	function startRefunding() public {
		refundActive = true;
		require(msg.sender == token.owner());
	}

	/**
	* @dev Function that processed a token sale
	* @return boolean success
	*/
	function buyTokens() public payable returns(bool) {
	// there are enough tokens available for sale
		require(token.balanceOf(address(this)) > token.fromWei(msg.value));
	// see if the buyer already has tokens and may be eligible for unclaimed past profit distributions
		uint256 unclaimedDistributions = token.getUnclaimedDistributions(msg.sender);
	// transfer purchased tokens from the store to the buyer
		uint256 tokens = token.transferInWei(msg.sender, msg.value);
		weiRaised = weiRaised.add(msg.value);
		emit TokenPurchase(	msg.sender,msg.sender,	msg.value,	tokens);
		if (unclaimedDistributions > 0)	{
	// transfer unclaimed earnings to the token buyer
			msg.sender.transfer(unclaimedDistributions);
		}
		if (weiRaised < financingGoal)	{
	// if initial financing goal hasn't been met yet - transfer sale proceeds to the special seed financing wallet			
			wallet.transfer(msg.value);
		}
		else	{
	// otherwise transfer proceeds to the token contract to be used in operating reserve			
			address(token).transfer(msg.value);
		}
		return true;
	}

	/**
	* @dev Function to process a profit sharing redemption request from a token holder
	* @return boolean success
	*/
	function claimProfitDistribution() public returns(bool) {
		require(token.balanceOf(msg.sender) > 0);
		uint256 unclaimedDistributions = token.getUnclaimedDistributions(msg.sender);
		if (unclaimedDistributions > 0)	{
			msg.sender.transfer(unclaimedDistributions);
		}
		return true;
	}

	/**
	* @notice Future use.  Need to define buyback strategy first	
	* @dev Function to process a token refund request 9buying back tokens) from a token holder
	* @param tokens number of tokens to be refunded
	* @return boolean success
	*/
	function refundTokens(uint256 tokens) public returns(bool) {
	// see if buy-back is ongoing
		require(token.validateBuyback(msg.sender, tokens));
	// calculate token intrinsic value		
		uint256 price = token.currentTokenValue();
	// burn bought-back tokens. Alternatively, they could be put up for sale again...
		uint256 refund = price.mul(tokens);
	// reduce running total of raised wei		
		weiRaised = weiRaised.sub(refund);
		emit TokenRefund(msg.sender,price,tokens,refund);
		token.burnFrom(msg.sender, tokens);
		msg.sender.transfer(refund);
		return true;
	}
}
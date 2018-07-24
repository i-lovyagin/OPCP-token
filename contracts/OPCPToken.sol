pragma solidity ^0.4.24;

// using base class template from the open-zeppelin project https://github.com/OpenZeppelin/openzeppelin-solidity
import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/StandardBurnableToken.sol";

/**
 * @title Operating Capital Pool token
 * @author Igor Lovyagin @i-lovyagin
*/

contract OPCPToken is StandardBurnableToken {

	string public constant name = "OPCP Token";
	string public constant symbol = "OPCP"; 
	uint8 public constant decimals = 4;

// unitialzed state of the accounting cycle timer
	uint256 public constant DISTANT_FUTURE = 1000 * 52 weeks;

	struct ServiceProvider	{
		string description;
		uint256 nextSettlement; // end of the next accounting cycle
		uint256 lockedTokens;  // tokens locked at registration
		bool active;  // status
		int128 earnings; // cumulative performance of linked customers 
		int128 cycleEarnings;	// 	cumulative performance linked customers during the current accounting cycle
	}

	struct Customer	{
		address provider;  // linked service provider
		uint256 balance;
	}

// structure created at the end of each profitable accounting cycle
	struct Distribution {
		uint256 amount;  // total gain during the accounting cycle
		uint256 tokenSupply; // total number of tokens that will receive profit distribution
		uint256 timestamp; 
	}

// service providers
	mapping(address=>ServiceProvider) public providers;
// customers
	mapping(address=>Customer) public customers;
// token holders and their respective indices into array of per-cycle profit distributions
// one a token holder claims his/her share of distribution, index is set to point to the end of the array
	mapping(address=>uint256) public claimedDistributions;
// contract owner == default service provider
	address public owner;
// storage of unsold tokens. This as the address of the sale contractt	
	address public tokenStore;  
// number of tokens locked at new provider registration	
	uint256 public spLockedTokens;
//service provider commission calculated as a percentage of provider-linked customer earnings	
	uint8 public spCommissionPct;
// how much profit provider's customers have to bring in for the locked tokens to be released
	uint256 public unlockRequirement;
// token to eth conversion rate - token price in Wei	
	uint256 public conversionRate;
// length of the accounting cycle in seconds
	uint256 public accountingCycle;
// target per-cycle per-token profit as a percentage 	
	uint8 public targetEarningsPct;
// token reserve asssigned the contract owner. These tokens are eligible to participate in 
// per-token profit distributions. They also function as a buffer that shrinks whenever ptrofit is below the target
// and some tokens from the reserve have to be burned to achive the required profit-to-token-supppy ratio
	uint256 public initialOwnerTokens;

// array of profit distribution records
	Distribution[] distributions;

// keeps track of the total ether amount locked in the processed profit sharing payouts that havben't been claimed yet
	uint256 public pendingPayouts;
// summary liability. Equals total deposits less total withdrawals plus/minus gaming session results as they come in
	uint256 public customerDeposits;
// end of the accounting cycle 
	uint256 public nextDistribution;
// summary earnings calculated as a sum of customer sessions for the current accounting cycle
	int128 public cycleEarnings;
// running counter of accounting cycles
	uint256 public cycleCount;
// flag that gets reset when initial funding gola is reached
	bool public bootstrapMode = true;
// token buy back functionality is being considered but hasn't been implemented yet
	uint256 public buybackTokens = 0;
/**
* Event generated on new service provider registration
* @param provider provider address
* @param lockedTokens number of tokens locked at registration
*/
	event ProviderRegistration(address indexed provider, uint256 lockedTokens);
/**
* Event generated when provider reaches cumulative profitability required for the tokens to be unlocked
* @param provider provider address
* @param earnings cumulative erarnings
*/
	event ProviderUnlock(address indexed provider, uint256 earnings);
/**
* Event generated when a token holder requests a profit sharing payouts
* @param holder token holder address
* @param amount payment amount
* @param lastCycle payment amount
*/
	event ProfitDistribution(address indexed holder, uint256 amount, uint256 lastCycle);
/**
* Event marking the end of accounting cycle
* @param cycleCount cycle sequence number
* @param cycleEarnings net cycle earnings
* @param pendingPayouts amount reserved for profit-sharing payouts
* @param customerDeposits summary liability
* @param tokenSupply  total token supply
*/
	event EndOfCycle(uint256 indexed cycleCount, int128 cycleEarnings, uint256 pendingPayouts, uint256 customerDeposits, uint256 contractBalance, uint256 tokenSupply);
/**
* Service provider cancels registration
* @param provider service provider address
* @param finalSettlement final commission payment
* @param burnedTokens tokens haven't been unlocked yet and will be burned
*/
	event ProviderCancelRegistration(address indexed provider, uint256 finalSettlement, uint256 burnedTokens);
/**
* Customer deposit
* @param customer customer address
* @param provider linked proviuder address
* @param fromAddress deposit message source address
* @param amount deposited amount 
*/	
	event CustomerDeposit(address indexed customer, address indexed provider, address indexed fromAddress, uint256 amount);
/**
* Customer withdrawal
* @param customer customer address
* @param provider linked proviuder address
* @param fromAddress deposit message source address
* @param amount withdrawn amount 
*/	
	event CustomerWithdrawal(address indexed customer, address indexed provider, address indexed fromAddress, uint256 amount);
/**
* Summary result of customer gaming session normally sent by the customer's provider
* @param customer customer address
* @param provider linked provider address
* @param fromAddress source address of the message. Some error conditions may result in this address 
		being different from the linked provide
* @param amount session outcome
*/	
	event CustomerSession(address indexed customer, address indexed provider, address indexed fromAddress, int128 amount);
/**
* Token supply increase. Tokens are minted and assigned to an address
* @param to address
* @param amount number of tokens
*/
	event Mint(address indexed to, uint256 amount);


	constructor(uint256 _totalSupply, 
			uint256 _rate, 
			uint8 _targetEarningsPct,
			uint256 _accountingCycleDays,
			uint256 _spLockedTokens,
			uint8 _spCommissionPct,
			uint8 _unlockMultiplier) public {
				
		totalSupply_ = toUnits(_totalSupply);
		conversionRate = fromUnits(_rate);
		balances[msg.sender] = totalSupply_;
		owner = msg.sender;
		targetEarningsPct = _targetEarningsPct;
		accountingCycle = _accountingCycleDays * (1 days);
		spLockedTokens = _spLockedTokens;
		spCommissionPct= _spCommissionPct;
		unlockRequirement = spLockedTokens * _unlockMultiplier;
		
		nextDistribution = DISTANT_FUTURE; // next distribution will be set to a meaningful value later

		// create a default provider account. Orphaned customers will be moved here. 
		providers[owner].description = "Default provider";
		providers[owner].active = true;
		providers[owner].nextSettlement = nextDistribution;

		emit Transfer(address(0), owner, totalSupply_);
	}

	/**
	* @dev Function to allocate a share of the total token supply to the contract owner and transfer the rest to the sale contract
	* @param _ownerTokensPct share of tokens allocated to contract owner expressed in term pf percentage points
	*/
	function setStore(uint8 _ownerTokensPct) public {
		initialOwnerTokens = totalSupply_.div(100).mul(_ownerTokensPct);
		tokenStore = msg.sender;
		balances[owner] = initialOwnerTokens;
		balances[tokenStore] = totalSupply_ - initialOwnerTokens; 
		emit Transfer(owner, tokenStore, totalSupply_ - initialOwnerTokens);
	}

	/**
	* @dev Function to register a new service provider, place lock on some of provider's tokens as a security measure
	* @param description description of a service provider being registered
	* @return boolean success
	*/
	function registerSP(string description) public returns(bool success) {
		require(!providers[msg.sender].active); // already registered
		require(balances[msg.sender] >= toUnits(spLockedTokens)); // can security deposit
	// initialize once when the first sp registers. This implicitely marks the start of normal opeartion with accounting cycles
		if (nextDistribution == DISTANT_FUTURE)	{ 
			nextDistribution = now + accountingCycle;
		}
		providers[msg.sender].description = description;
		providers[msg.sender].nextSettlement = now + accountingCycle;
		providers[msg.sender].lockedTokens = toUnits(spLockedTokens);
		providers[msg.sender].active = true;
		providers[msg.sender].cycleEarnings = 0;
		providers[msg.sender].earnings = 0;

		emit ProviderRegistration(msg.sender, toUnits(spLockedTokens));
		
		return true;
	}

	/**
	* @dev Function to unregister a service provider.  If profitable, pay the last commission. Otherwise, confiscate tokens and burn them. 
	* Also, burn locked tokens if any
	* @return boolean success
	*/
	function unregisterSP() public returns(bool success) {
		require(providers[msg.sender].active); // registration exists and is active. Uninitialized bool is false
		require(msg.sender != owner);  // don't unregister the default provider - owner
		providers[msg.sender].active = false;
		int128 gain = providers[msg.sender].cycleEarnings;   
		uint256 tokensToBurn  = providers[msg.sender].lockedTokens;
		if (gain < 0)	{
	// cycle loss converted to commission converted to tokens
			uint256 lossInTokens = fromWei(uint256(0 - gain).div(100).mul(spCommissionPct));
			if (lossInTokens <= balances[msg.sender])	{
	// compensate losses by confiscating provider's tokens
				tokensToBurn += lossInTokens;
			}
			else	{
	// not enough tokens to compensate for the loss in full. Take all of the provider's tokens				
				tokensToBurn += balances[msg.sender];  
			}
		}
		else	{
	// settle current cycle profits
			msg.sender.transfer(uint256(gain).div(100).mul(spCommissionPct));
		}
	// burn tokens that haven't been unlocked yet plus compensation for the current cycle loss if any
		if (tokensToBurn > 0)	{
			burn(tokensToBurn);
		}
		emit ProviderCancelRegistration(msg.sender, uint256(gain), tokensToBurn);
		return true;
	}

	/**
	* @dev Function to handle an ether deposit coming from a customer address
	* @param _provider address of a service provider linked to the depositing customer
	* @return boolean success
	*/
	function customerDirectDeposit(address _provider) public payable returns(bool success)	{
	// increase customer balance		
		customers[msg.sender].balance = customers[msg.sender].balance.add(msg.value);
 	// inactive service provider. Assign customer to a default provider(contract owner)		
		customers[msg.sender].provider = providers[_provider].active ? _provider : owner;
	// maintain running total of customer balances (liability)
		customerDeposits = customerDeposits.add(msg.value);
		emit CustomerDeposit(msg.sender, customers[msg.sender].provider, msg.sender, msg.value);
		return true;
	}

	/**
	* @dev Function to handle an ether deposit coming from a provider depositing on behalf of its customer
	* @param _customer address of a customer  linked to the depositing service provider
	* @return boolean success
	*/
	function customerDeposit(address _customer) public payable returns(bool success)	{
		require(providers[msg.sender].active);  // inactive or invalid provider
		customers[_customer].balance = customers[_customer].balance.add(msg.value);
		customers[_customer].provider = msg.sender;
		customerDeposits = customerDeposits.add(msg.value);
		emit CustomerDeposit(_customer, msg.sender, msg.sender, msg.value);
		return true;
	}

	/**
	* @dev Function to handle a withdrawal request coming from a customer address
	* @param _amount amount of withdrawl
	* @return boolean success
	*/
	function customerDirectWithdrawal(uint256 _amount) public returns(bool success)	{
	// see if requested amount doesn't exceed customer balance
		require(customers[msg.sender].balance >= _amount);
	// see if this amount is available. This check is propably unnecessary. If it fails, contract code must be very buggy		
		require(customerDeposits >= _amount);
		customers[msg.sender].balance = customers[msg.sender].balance.sub(_amount);
		msg.sender.transfer(_amount);
		customerDeposits = customerDeposits.sub(_amount);
		emit CustomerWithdrawal(msg.sender, customers[msg.sender].provider, msg.sender, _amount);
		return true;
	}

	/**
	* @dev Function to handle a customer withdrawal request coming from a provider on behalf of its customer
	* @param _customer address of a customer  linked to the requesting service provider
	* @param _amount amount of withdrawl
	* @return boolean success
	*/
	function customerWithdrawal(address _customer, uint256 _amount) public returns(bool success)	{
	// see if requesting provider is assigned to the withdrawing customer
		require(customers[_customer].provider == msg.sender);
	// see if requested amount doesn't exceed customer balance
		require(customers[_customer].balance >= _amount);
		require(customerDeposits > _amount);
		customers[_customer].balance = customers[_customer].balance.sub(_amount);
	// transfer funds to the customer address
	// TODO this is a risky pattern. Customer address may be that of a malicious contract. 
		_customer.transfer(_amount);
		customerDeposits = customerDeposits.sub(_amount);
		emit CustomerWithdrawal(_customer, customers[_customer].provider, msg.sender, _amount);
		return true;
	}

	/**
	* @dev Function to process a summary outcome of a customer gaming session. Message is sent by the customer's provider
	* @param _customer address of a customer linked to the reporting service provider
	* @param _amount session outcome in wei
	* @return boolean success
	*/
	function customerSession(address _customer, int128 _amount) public returns(bool success)	{
    // Impossible condition: customer can't be active with zero balance		
		require(customers[_customer].balance > 0);
	// Customer's provider is no longer active. Reassign customer to the default provider (contract owner)
		if (!providers[msg.sender].active)	{
			customers[_customer].provider= owner;  // move to the default provider
		}
	// Add session outcome the provider's runnign total for the current accounting cycle. 
	// Ignore if customer's provider is the contract owner		
		if (customers[_customer].provider != owner) 	{
			providers[customers[_customer].provider].cycleEarnings += _amount;
		}
	// Update customer bvalance		
		if (_amount > 0)	{
			customerDeposits = customerDeposits.add(uint256(_amount));
		}
		else	{
			customerDeposits = customerDeposits.sub(uint256(0 - _amount));
		}
    // Update global summary earnings for the current accounting cycle		
		cycleEarnings += _amount;
		emit CustomerSession(_customer, customers[_customer].provider, msg.sender, _amount);
		return true;
	}

	/**
	* @dev Function to handle processing of a commission payout request coming from a service provider
	* @return boolean success
	*/
	function settleRequest() public triggerProfitDistribution returns(bool success)	{
	// requesting provieder has to be active		
		require(providers[msg.sender].active);  
	// full cycle duration has lapsed since the previously procissed accouting cycle		
		require(providers[msg.sender].nextSettlement <= now);
	// update time of the end of the new accounting cycle
		providers[msg.sender].nextSettlement = now + accountingCycle; 
	// summary performance of all customers assigned to the service provider during the last accounting cycle
		int128 earnings = providers[msg.sender].cycleEarnings;
		providers[msg.sender].cycleEarnings = 0;
		providers[msg.sender].earnings += earnings; // TODO safety
		if (earnings > 0)	{
	// providers customers denerated profit. Calculate commission earned by the provider
			uint256 amount = uint256(earnings).mul(spCommissionPct).div(100);
	// net lifetime earnings exceediing the lock requirement release locked tokens
			if (providers[msg.sender].earnings > int128(unlockRequirement))	{
				providers[msg.sender].lockedTokens = 0;  // release locked tokens 
				emit ProviderUnlock(msg.sender, uint256(providers[msg.sender].earnings));
			}
			msg.sender.transfer(amount);  // send hard earned ethers to the provider
		}
		return true;
	}

	/**
	* @dev Function to calculate the amount owed to the token holder eligible for profit sharing payouts in proportion to the held tokens count
	* @param holder address of the token holder
	* @return boolean success
	*/
	function getUnclaimedDistributions(address holder) public returns(uint256)	{
	// retrieve information about last claimed distribution for this token holder
		uint256 startingCycle = claimedDistributions[holder]; 
	// number of held tokens		
		uint256 heldTokens = balanceOf(holder); 
		uint256 payment = 0;
	// loop through array of token distributions starting from the chronologically first 
	// distribution that hasn't been claimed by this holder yet
		if (heldTokens > 0)	{
			for (uint256 i = startingCycle; i < distributions.length; i++)	{
				// each distribution record stores the amount of distribution and the number of tokens eligible for sharing
				payment = payment.add(distributions[i].amount.div(distributions[i].tokenSupply).mul(heldTokens));
			}

		}
	// set the "last claimed" pointer 
		claimedDistributions[holder] = distributions.length;
		if (payment > 0)	{
			pendingPayouts = pendingPayouts.sub(payment);
			emit ProfitDistribution(holder, payment, claimedDistributions[holder]);			
		}
		return payment;
	}

	/**
	* @dev Modifier that checks to see if the current accounting cycle is over and it's time to process profit sharing distribuition to the token holders
	*/
    modifier triggerProfitDistribution()	{
        _;
    // cycle has ended	
		if (nextDistribution <= now)	{
	// set the next cycle end
			nextDistribution = now + accountingCycle;  
	// net gain from customer sessions
			if (cycleEarnings > 0)	{
				uint256 gain = uint256(cycleEarnings);
				cycleEarnings = 0;
	// size of the array storing earlier end-of-cycle distributions
				uint256 sequence = distributions.length;
	// initialize Distribution structure with data from the cycle being closed
				Distribution memory d = Distribution(gain, totalSupply_.sub(balances[tokenStore]), now);  
	// add to the distributions array. Now the token holder can request payouts in proportion to their token holdings
				distributions.push(d); 
	 // keep track of summary reserved payouts				 
				pendingPayouts += gain;
				emit EndOfCycle(cycleCount, int128(gain), pendingPayouts, customerDeposits, address(this).balance, totalSupply_);
				setReservePolicy(gain);
			}
			else{
				// it's a loss. Postpone alll calculations and distributions until the end of next cycle
				emit EndOfCycle(cycleCount, cycleEarnings, pendingPayouts, customerDeposits, address(this).balance, totalSupply_);
			}
			cycleCount++;
		}
    }

	/**
	* @dev Function to maintain the size of a token supply in proportion to the net gain during an accounting cycle. The goal is to keep
	* per-token share of earnings constant
	* @param gain earnings during the accounting cycle being processed
	*/
	function setReservePolicy(uint256 gain) internal {
		if (!bootstrapMode)	{
	// "required" number of tokens that would make realized per-token-gain match the target setting
			uint256 requiredTokenSupply =fromWei( gain.div(targetEarningsPct).mul(100));
	//	required supply is less than total supply
			if (requiredTokenSupply < totalSupply_)	{
	// calculate the surplus
				uint256 surplus =  totalSupply_ - requiredTokenSupply;
				if (surplus <= balances[owner])	{
	// number of extra tokes is less than the token count held by the contracxt owner				
					_burn(owner, surplus);
				}
				else	{
	// number of extra tokes is greater than the token count held by the contracxt owner				
	// burn ALL of the owner's tokens
					surplus -= balances[owner];
					_burn(owner, balances[owner]);
	// attempt to buy back the remaining surplus
					buybackTokens = buybackTokens.add(surplus);
				}
			}
			else	{
				buybackTokens = 0;
	// not enough tokens to distribute profits at a pre-configured per-token level. Calculate the deficit
				uint256 deficit =  requiredTokenSupply - totalSupply_;
	    		totalSupply_ = totalSupply_.add(deficit);
				if (initialOwnerTokens > balances[owner])	{
	// some of the contract owner's tokens have been burned during an earlier cycle
					uint256 ownerDeficit = initialOwnerTokens - balances[owner];
					if (deficit >= ownerDeficit)	{
	// overall shortage of tokens is greater than the number of tokens missing from the contract owner's reserve						
						deficit -= ownerDeficit;
	// mint new tokens to the contract owner						
						balances[owner] += ownerDeficit;
					    emit Mint(owner, ownerDeficit);
						if (deficit > 0)	{
	// mint the remaining tokens and put them up for sale						
			    			balances[tokenStore] = balances[tokenStore].add(deficit);
						    emit Mint(tokenStore, deficit);
						}
					}
					else	{
	// partially restore contract owner's reserve by minting new tokens to the contract owner
						balances[owner] += deficit;
					    emit Mint(owner, deficit);
					}
				}
			}
		}

	}


	/**
	* @notice reserved for future use. Need to define a buyback strategy first
	* @dev Function to check the validity of attempted sale of tokens back to the store 
	* @param holder address of the requesting token holder
	* @param requestedBuybackInWei amount in wei specified by the token holder to indicate the size of the requested buy-back transaction
	* @return boolean success
	*/
	function validateBuyback(address holder, uint256 requestedBuybackInWei) public view returns(bool)	{
		uint256 tokens = fromWei(requestedBuybackInWei);
		return ((balances[holder] >= tokens) && (tokens <= buybackTokens));
	}


	/**
	* @dev Function to handle the sale of tokens. Moves tokens from the store to the buyer
	* @param _beneficiary address of the token buyer
	* @param weiAmt wei amount paid for purchase
	* @return number of tokens sold
	*/	
	function transferInWei(address _beneficiary, uint256 weiAmt) public returns(uint256)	{
		uint256 tokens = weiAmt.div(conversionRate);
		if (transfer(_beneficiary, tokens))	{
			return tokens;
		}
		return 0;
	}

	/**
	* @notice reserved for future use. Need to define a buyback strategy first
	* @dev Function calculates current value of a token using the token contract balance less the sum of all liabilities
	* @return single token value in wei
	*/
	function currentTokenValue() public view returns (uint256) {
		uint256 availableBalance = address(this).balance - pendingPayouts - customerDeposits;
		uint256 redeemableTokens = 	totalSupply_ - balances[owner] - balances[tokenStore];
		return availableBalance.div(redeemableTokens);
	}

	/**
	* @dev Fallback function allowing to send ether to the contract
	*/
    function () public payable {}

	/**
	* @dev Utility function to convert amount in Weis to the number of tokens
	* @param amtWei amount in Wei
	* @return number of tokens
	*/
	function fromWei(uint256 amtWei) public view returns (uint256 tokens)	{
		return amtWei.div(conversionRate);
	}

	/**
	* @dev Utility function to convert number of tokens to the corresponding amount in Wei
	* @param tokens number of tokens
	* @return amount in Wei
	*/
	function toWei(uint256 tokens) public view returns (uint256 amtWei)	{
		return tokens.mul(conversionRate);
	}

	/**
	* @notice internal arithmetic adds four decimal points to the token counts used by external API's
	* @dev Utility function to convert internally used units to tokens recognized in outside world
	* @param units number of units
	* @return corrsponding number of tokens
	*/
	function fromUnits(uint256 units) public pure returns (uint256 tokens)	{
		return units.div(uint256(10)**decimals);
	}


	/**
	* @notice internal arithmetic adds four decimal points to the token counts recognized by external API's
	* @dev Utility function to convert tokens to internally used units 
	* @param units number of tokens
	* @return corrsponding number of units
	*/
	function toUnits(uint256 units) public pure returns (uint256 tokens)	{
		return units.mul(uint256(10)**decimals);
	}

	/**
	* @notice internal arithmetic adds four decimal points to the token counts recognized by external API's
	* @dev Utility function to report token balance of an account measured in externally recognized tokens as opposed to the internally used units
	* @param _of token holder address
	* @return corrsponding number of units
	*/
	function balanceOfAdj(address _of) public view returns(uint256)	{
		return balanceOf(_of).div(uint256(10)**decimals);
	}

	/**
	* @dev Function to burn tokens belonging to the specified address
	* @param _from token holder address
	* @param _value number of tokens to be burned
	*/
	function burnFrom(address _from, uint256 _value) public {
		require(buybackTokens > _value);  // this should never happen after earlier checks. Remove from production verions
		buybackTokens -= _value;
    	_burn(_from, _value);
  	}

	/**
	* @notice functions that are only needed for testing purposes. Will be removed in production
	*/

	function testForceEndCycle(address _sp) public {
		require(msg.sender == owner);
		nextDistribution = now - 1;
        if (_sp != owner)	{ // contract expiration
			providers[_sp].nextSettlement = now - 1;
		}
	}
}

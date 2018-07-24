# OPCP-token
ERC20 compatible operating capital pool token

Motivation 

Operating capital pool (OPCP) token is modeled after a business that’s characterized by a high volume of micro transactions with its end users. Outcome of a single transaction can be either a win or a loss for the business. Summary outcome of a statistically significant set of transactions, however, is always a calculable gain. 

Such business model creates a need for a capital reserve that serves as a buffer and absorbs occasional short-term losses. As an investment mechanism, however, this reserve is guaranteed to be profitable in the long run.

To put this model into perspective, we can use an on-line gambling site as an example. Site’s end users, gamblers, sometimes win and sometimes lose, but the long term result is always a net win for the house. Most if not all of the online casino games have well-researched statistical models behind them allowing for a fairly reliable prediction of their monetary performance.

For such a site to stay in business and maintain profitability, a number of conditions must be met: its customers shouldn’t be allowed to cheat, it should remain solvent in an event of a lucky player hitting the jackpot a couple of times in a row, its software engine should be hacker-proof with assured integrity of its random number generator . 

A commonly found setup behind an online casino site licensed for operations in European markets is as follows. Game logic is typically outsourced to a Remote Gaming Server (RGS) licensed to operate in the target jurisdictions. User account management and banking are also outsourced to the same or, in some cases, separate third party provider. Either way, the site operator is responsible for putting together the package, bringing the site up, marketing it and being able to withstand an occasional downturn in profits. 

Financial requirement of this model create a significant barrier to entry. OPCP token is designed to eliminate that barrier by implementing a crowd funding scheme that would enable small investors to share in the profits of an online casino.

Top level overview

ERC20-based OPCP token and OPCP token sale contracts are deployed to the Ethereum Blockchain. Part of the initial token supply is allocated to the token reserve and the rest are offered for sale.  At this stage, all proceeds go to the research, development, and marketing budgets. After reaching a predefined funding goal, proceeds start accumulating in the OPCP contract forming an operating capital reserve.  Having reached its second level funding objective, OPCP contract starts accepting registration requests from the service providers marking the start of its normal operations. At this point it has two reserves:

- ether reserve to be used as a buffer protecting against fluctuations in earnings
- OPCP token reserve that is used to adjust token supply to stabilize per-token profit sharing payouts

Service providers are the key element of the OPCP ecosystem. They launch, maintain and market web sites offering casino-style games to their clientele. OPCP contract keeps track of the summary performance by each provider’s respective customers and, at the end of each accounting cycle,  uses the cumulative value to calculate and pay out service providers’ commissions.

Having distributed service providers’ commissions, OPCP contract is left with the residual gain that is distributed to the token holders. 

Contract tries to maintain per-token payouts at the predefined level by adjusting token supply at the end of each accounting cycle. In a situation where the token supply needs to be reduced to match the decrease in earnings, tokens from the reserved are burned. In the opposite scenario, new tokens are minted and used to restore token reserve balance or sold when reserve is full. 

OPCP contract balance stores ether capital reserve as well as casino customer deposits. Contract keeps track of customer account balances and adjusts them in accordance with gaming session outcome data received from the respective service providers.

Major components

OPCP token contract

- Interacts with services providers and their respective customers
- Implements basic accounting based on predefined accounting periods
- Keeps track of service providers’ performance measured as a summary revenue of their respective customers
- Pays commission to a service provider that is calculated as a percentage of attributed earnings
- Stores capital reserve used as a buffer that sustains operations through the periods of negative gaming revenue
- Stores customer’s deposits and withdrawals
- Distributes profits at the end of each accounting period to the token holders. Profits are allocated to the entire token supply with the exception of the unsold tokens
- Maintains predefined per-token profitability levels by minting new tokens at the end of each accounting period or burning tokens from the token reserve.

OPCP token sale contract

- Facilitates sale of OPCP tokens
- During the initial development stage of the project sends proceeds from the sale of tokens to a predefined wallet address. Development budget is predefined and,once it’s reached, proceeds are forwarded to the OPCP token contract to serve as an operating capital reserve 

Service providers 

- Service providers operate web sites that offer online gambling. They are responsible for the creation of site content, its operations and marketing. Service providers facilitate customer banking by acting as a fiat-to-ether exchange or by passively redirecting customer deposits/withdrawals in ethers to OPCP token contract running on the EVM (Ethereum Virtual Machine). 
- In addition to being an intermediary between the end users and the OPCP contract, service providers run an instance of the gaming server which, in addition to being responsible for  the handling of all gaming logic, serves as a validating node on a private sub-chain consisting of multiple game-server-nodes.
- Service providers earn a commission. Commission is calculated as a percentage of net earnings from the customers linked to a specific service provider. 
- Only OPCP token holders are allowed be registered as a service provider. Upon initial registration a fixed number of their tokens is locked and can no longer be re-sold on the secondary market. The lock is lifted once the summary earnings from the service provider’s customer base reach a predefined threshold.
- To open a new gaming session, service provider receives an authentication request from a customer and attempts to lock customer’s balance in the OPCP contract. The lock blocks deposits/withdrawals from the customer account for the duration of gaming session. 
- At the end of each gaming session, service provider reports summary session outcome to the OPCP contract. OPCP adjusts customer balance accordingly and unlocks the customer account.

Project status

Before moving to production, the contract code will need some cleaning and minor optimization. Also, addition of some elements of DAO-style governance may be considered. However, that is not the main focus of the work on the project at this point.

OPCP token used with online casino web sites relies on the game servers driving the game logic and reporting back the result. Due to its block chain-based nature, server software presents several challenges not present in a traditional system:

- Secure method of generating random numbers. Nothing is private on a block chain. Same goes for the seed numbers used to generate pseudo-random sequences. An acceptable solution must not compromise user experience by slowing games down. It should also preserve decentralization which would be sacrificed if randomness is generated off-chain by oracles.
- Assuring that the game server hasn’t been hacked and player session data reported back to OPCP contract can be trusted. Game servers running in a traditional setup have to be protected from outside hackers and that in and of itself is a challenge. Blockchain-based decentralized environment creates an additional threat by incentivizing web site operators who also host instances of game server software to hack their own installations.

Besides these two fundamental challenges presented by decentralization, there are few other less obvious requirements that would have to be satisfied for a game server solution to be acceptable. And that is the area where current work on the project is focused.

Alternative applications

Even though most of the logic behind the current implementation draws from the business model of an online casino, it doesn’t mean that that is the only area where OPCP tokens can be used. Using it for sports betting, for example, is probably less technologically challenging as it doesn’t use random numbers and correctness of sports wager grading is easily verifiable. 
Another area where OPCP token could prove useful is in a network of micro loan (payday loan) providers. The key element here would be to create an operational model that would allow the risk, i.e. probability of non-payment, to be programmable. Intuitively, this should be solved by using oracles linked to the external banking and/or credit rating databases.
